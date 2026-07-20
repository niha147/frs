import numpy as np
from app.core.logging import logger

try:
    import cv2
    OPENCV_AVAILABLE = True
except ImportError:
    OPENCV_AVAILABLE = False
    logger.warning("OpenCV is not available. Image processing will run in Simulation Mode.")

import io
from PIL import Image

def decode_image(image_bytes: bytes) -> np.ndarray:
    """Decodes raw image byte streams into a BGR image matrix using OpenCV or PIL."""
    if OPENCV_AVAILABLE:
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if image is not None:
            return image
            
    try:
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        # Convert RGB to BGR numpy array
        rgb_array = np.array(pil_image)
        bgr_array = rgb_array[:, :, ::-1].copy()
        return bgr_array
    except Exception as e:
        raise ValueError(f"Failed to decode image bytes: {str(e)}")

def draw_face_box(image: np.ndarray, bbox: list, label: str) -> np.ndarray:
    """Draws a rectangular overlay and a name/confidence label on the image."""
    if not OPENCV_AVAILABLE:
        return image
        
    x1, y1, x2, y2 = [int(coord) for coord in bbox]
    # Draw green bounding box (BGR format)
    cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
    # Write name label above box
    cv2.putText(
        image, 
        label, 
        (x1, max(y1 - 10, 15)), 
        cv2.FONT_HERSHEY_SIMPLEX, 
        0.5, 
        (0, 255, 0), 
        1, 
        cv2.LINE_AA
    )
    return image
