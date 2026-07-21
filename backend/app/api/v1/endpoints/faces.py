import uuid
from typing import List
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.api import deps
from app.ai.face_embedding import FaceEmbeddingService
from app.ai.liveness import LivenessService
from app.ai.image_utils import decode_image
from app.models.faculty import Faculty
from app.models.student import Student
from app.models.face_embedding import FaceEmbedding
from app.schemas.face import FaceOut
from app.services.storage import SupabaseStorageService

router = APIRouter()
face_service = FaceEmbeddingService()
liveness_service = LivenessService()
storage_service = SupabaseStorageService()

@router.post("/students/{student_id}/faces", response_model=FaceOut, status_code=status.HTTP_201_CREATED)
async def register_student_face(
    student_id: uuid.UUID,
    file: UploadFile = File(..., description="Image file containing student face"),
    is_primary: bool = Form(False, description="Set this as the primary identification photo"),
    blink_simulated: bool = Form(True, description="Guided liveness check: Eye blink simulation flag"),
    yaw_simulated: bool = Form(True, description="Guided liveness check: Head turn simulation flag"),
    smile_simulated: bool = Form(True, description="Guided liveness check: Smile simulation flag"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
):
    """
    Registers a student face photo. Performs:
    1. Liveness checks (guided parameters).
    2. Embedding extraction (InsightFace 512-d).
    3. Duplicate face prevention check (blocks uploads matching existing students).
    4. Local disk saving and database registration.
    """
    # 1. Verify target student exists
    student_query = select(Student).where(Student.id == student_id)
    student_result = await db.execute(student_query)
    student = student_result.scalars().first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    # 2. Read image file contents
    image_bytes = await file.read()
    
    # 3. Decode image using OpenCV BGR helper
    try:
        image_matrix = decode_image(image_bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Could not decode image: {str(e)}"
        )

    # 4. Perform liveness verification
    liveness_passed, reason = liveness_service.verify_liveness(
        image_matrix,
        blink_simulated=blink_simulated,
        yaw_simulated=yaw_simulated,
        smile_simulated=smile_simulated
    )
    if not liveness_passed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=reason
        )

    # 5. Extract face embedding vector
    try:
        embedding = face_service.extract_embedding_from_bytes(image_bytes, image_matrix)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

    # 6. Duplicate Face check (Query all registered face embeddings in database)
    all_embeddings_query = select(FaceEmbedding)
    all_embeddings_result = await db.execute(all_embeddings_query)
    db_embeddings = all_embeddings_result.scalars().all()
    
    from app.core.config import settings
    for db_emb in db_embeddings:
        similarity = face_service.compute_similarity(embedding, db_emb.embedding)
        if similarity > settings.FACE_DUPLICATE_THRESHOLD:
            # Face matches an existing registration
            if db_emb.student_id != student_id:
                # Fetch details of the matched student
                other_student_query = select(Student).where(Student.id == db_emb.student_id)
                other_student_result = await db.execute(other_student_query)
                other_student = other_student_result.scalars().first()
                other_name = other_student.name if other_student else "another student"
                
                # Returns consistent error envelope as required
                return JSONResponse(
                    status_code=status.HTTP_409_CONFLICT,
                    content={
                        "error": {
                            "code": "DUPLICATE_FACE",
                            "message": f"This face matches an existing student: {other_name}.",
                            "details": {
                                "matched_student_id": str(db_emb.student_id),
                                "matched_student_name": other_name,
                                "similarity_score": similarity
                            }
                        }
                    }
                )

    # 7. Save file using Storage Service
    file_extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    unique_filename = f"{student_id}_{uuid.uuid4().hex}.{file_extension}"
    saved_path = await storage_service.save_file(image_bytes, unique_filename, "faces")

    # 8. Manage is_primary constraint (only one primary photo per student)
    if is_primary:
        # Reset all other face embeddings for this student to False
        reset_query = select(FaceEmbedding).where(
            (FaceEmbedding.student_id == student_id) & (FaceEmbedding.is_primary == True)
        )
        reset_result = await db.execute(reset_query)
        for primary_emb in reset_result.scalars().all():
            primary_emb.is_primary = False
            db.add(primary_emb)

    # 9. Write face embedding record
    db_face = FaceEmbedding(
        student_id=student_id,
        embedding=embedding,
        image_path=saved_path,
        is_primary=is_primary
    )
    db.add(db_face)
    await db.flush()
    
    return db_face

@router.get("/students/{student_id}/faces", response_model=List[FaceOut])
async def list_student_faces(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[FaceOut]:
    """Retrieve all registered face profile vectors for a student."""
    query = select(FaceEmbedding).where(FaceEmbedding.student_id == student_id)
    result = await db.execute(query)
    return list(result.scalars().all())

@router.delete("/students/{student_id}/faces/{face_id}")
async def delete_student_face(
    student_id: uuid.UUID,
    face_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> dict:
    """Deletes a specific face embedding record and removes the file from local storage."""
    query = select(FaceEmbedding).where(
        (FaceEmbedding.id == face_id) & (FaceEmbedding.student_id == student_id)
    )
    result = await db.execute(query)
    face_record = result.scalars().first()
    if not face_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Face record not found for this student."
        )

    # Delete local file
    await storage_service.delete_file(face_record.image_path)
    
    # Delete DB record
    await db.delete(face_record)
    await db.flush()

    return {"status": "ok", "message": "Face record deleted successfully."}
