import numpy as np
from app.core.logging import logger

try:
    import cv2
    OPENCV_AVAILABLE = True
except ImportError:
    OPENCV_AVAILABLE = False
    logger.warning("OpenCV is not available. Image processing will run in Simulation Mode.")

def decode_image(image_bytes: bytes) -> np.ndarray:
    """Decodes raw image byte streams into an OpenCV BGR image matrix."""
    if not OPENCV_AVAILABLE:
        # Return a simulated empty image matrix (numpy array)
        return np.zeros((480, 640, 3), dtype=np.uint8)
        
    nparr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Failed to decode image bytes: Invalid image format.")
    return image

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
