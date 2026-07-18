import hashlib
import random
from typing import List, Optional
import numpy as np
from app.core.logging import logger

try:
    import insightface
    from insightface.app import FaceAnalysis
    INSIGHTFACE_AVAILABLE = True
except ImportError:
    INSIGHTFACE_AVAILABLE = False
    logger.warning("InsightFace is not available. Embedding operations will run in Simulation Mode.")

class FaceEmbeddingService:
    def __init__(self):
        self.app = None
        if INSIGHTFACE_AVAILABLE:
            try:
                # Load buffalo_l pack using CPU execution providers (or GPU if available)
                self.app = FaceAnalysis(name="buffalo_l", providers=['CPUExecutionProvider'])
                # Initialize detection and analysis context (uses detection threshold 0.5)
                self.app.prepare(ctx_id=0, det_size=(640, 640))
                logger.info("InsightFace app (buffalo_l) initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to load InsightFace model: {str(e)}. Falling back to Simulation Mode.")
                self.app = None

    def is_simulation_mode(self) -> bool:
        """Helper to check if the AI service is running in mock/simulation mode."""
        return self.app is None

    def extract_embedding_from_bytes(self, image_bytes: bytes, image_matrix: np.ndarray) -> List[float]:
        """
        Extracts a 512-dimension face embedding vector from image bytes or matrix.
        If InsightFace is initialized, analyzes the image, identifies the largest face, and returns its embedding.
        Otherwise, falls back to a deterministic 512-d unit vector seeded by the SHA256 of the image bytes.
        """
        if self.app is not None:
            try:
                # Analyze image matrix (expects BGR)
                faces = self.app.get(image_matrix)
                if not faces:
                    raise ValueError("No faces detected in the image.")
                if len(faces) > 1:
                    raise ValueError("Multiple faces detected in the frame. Only single-face uploads allowed.")
                
                # Retrieve the embedding (normally a numpy float32 array)
                raw_emb = faces[0].embedding
                # Normalize the embedding to unit scale for cosine calculations
                norm = np.linalg.norm(raw_emb)
                if norm > 0:
                    raw_emb = raw_emb / norm
                return raw_emb.tolist()
            except Exception as e:
                if "detected" in str(e):
                    raise e
                logger.warning(f"Error running native InsightFace analysis: {str(e)}. Falling back to mock embedding.")
                # Fall back to simulation below if native extraction fails

        # --- SIMULATION FALLBACK ---
        # Generate a deterministic 512-dimension unit vector seeded by the SHA256 of the uploaded file bytes.
        # This guarantees that:
        # 1. The exact same image file will always produce the exact same embedding.
        # 2. Different image files will produce different embeddings.
        # 3. Embedding matches (dot product similarity) behave mathematically like real cosine similarities.
        sha256_hash = hashlib.sha256(image_bytes).hexdigest()
        # Seed Python's standard RNG with a chunk of the hash
        seed_value = int(sha256_hash[:8], 16)
        rng = random.Random(seed_value)
        
        # Generate random values under a Gaussian distribution
        simulated_vector = [rng.gauss(0, 1) for _ in range(512)]
        # Normalize vector to unit length
        vector_norm = sum(coord ** 2 for coord in simulated_vector) ** 0.5
        normalized_vector = [coord / vector_norm for coord in simulated_vector]
        
        return normalized_vector

    @staticmethod
    def compute_similarity(embedding1: List[float], embedding2: List[float]) -> float:
        """
        Computes the cosine similarity between two unit-normalized 512-d embeddings.
        Since both input vectors are normalized to length 1.0, the cosine similarity
        is equal to the dot product of the vectors.
        """
        if len(embedding1) != 512 or len(embedding2) != 512:
            raise ValueError("Embeddings must have exactly 512 dimensions.")
            
        similarity = sum(coord1 * coord2 for coord1, coord2 in zip(embedding1, embedding2))
        return float(similarity)
