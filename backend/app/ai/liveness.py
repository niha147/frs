from app.core.logging import logger

try:
    import mediapipe as mp
    MEDIAPIPE_AVAILABLE = True
except ImportError:
    MEDIAPIPE_AVAILABLE = False
    logger.warning("MediaPipe is not available. Liveness verification will run in Simulation Mode.")

class LivenessService:
    """
    Coordinates guided liveness checks on input video frames/images.
    Calculates landmask geometry:
    - Eye Aspect Ratio (EAR) to detect eye blinks.
    - Head pose Yaw estimations to detect horizontal turns.
    - Mouth Aspect Ratio (MAR) to detect smiles.
    """
    
    def __init__(self):
        self.mp_face_mesh = None
        if MEDIAPIPE_AVAILABLE:
            try:
                self.mp_face_mesh = mp.solutions.face_mesh.FaceMesh(
                    static_image_mode=True,
                    max_num_faces=1,
                    refine_landmarks=True,
                    min_detection_confidence=0.5
                )
                logger.info("MediaPipe Face Mesh initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize MediaPipe Face Mesh: {str(e)}. Using simulation.")
                self.mp_face_mesh = None

    def verify_liveness(
        self,
        image_matrix,
        challenge_type: str = None,
        blink_simulated: bool = True,
        yaw_simulated: bool = True,
        smile_simulated: bool = True,
        pitch_simulated: bool = True
    ) -> tuple[bool, str]:
        """
        Validates blink, head turn, smile, or look up/down based on challenge type.
        Returns (success: bool, reason: str).
        """
        import math
        
        def dist(p1, p2):
            return math.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2 + (p1.z - p2.z)**2)

        if self.mp_face_mesh is not None:
            try:
                # Run real MediaPipe landmark detection
                import cv2
                rgb_image = cv2.cvtColor(image_matrix, cv2.COLOR_BGR2RGB)
                results = self.mp_face_mesh.process(rgb_image)
                
                if not results.multi_face_landmarks:
                    return False, "No face detected in the frame."
                
                # Retrieve landmarks (478 coordinates total)
                landmarks = results.multi_face_landmarks[0].landmark
                
                if challenge_type == "blink":
                    # --- EYE BLINK DETECTION (EAR) ---
                    # Left eye indexes: 33, 160, 158, 133, 153, 144
                    # Right eye indexes: 362, 385, 387, 263, 373, 380
                    p33, p160, p158, p133, p153, p144 = [landmarks[i] for i in [33, 160, 158, 133, 153, 144]]
                    p362, p385, p387, p263, p373, p380 = [landmarks[i] for i in [362, 385, 387, 263, 373, 380]]
                    
                    ear_left = (dist(p160, p153) + dist(p158, p144)) / (2.0 * dist(p33, p133))
                    ear_right = (dist(p385, p380) + dist(p387, p373)) / (2.0 * dist(p362, p263))
                    ear = (ear_left + ear_right) / 2.0
                    
                    if ear > 0.22:
                        return False, f"Liveness check failed: Eye blink not detected (EAR {ear:.2f} > 0.22)."
                    return True, f"Blink check passed (EAR: {ear:.2f})."
                    
                elif challenge_type == "smile":
                    # --- SMILE DETECTION (MAR & Width) ---
                    # Mouth corners: 61, 291
                    # Lips: 13, 14
                    p61, p291, p13, p14 = [landmarks[i] for i in [61, 291, 13, 14]]
                    p234, p454 = landmarks[234], landmarks[454]
                    
                    mar = dist(p13, p14) / dist(p61, p291)
                    smile_ratio = dist(p61, p291) / dist(p234, p454)
                    
                    # A smile opens the mouth slightly and widens the mouth corners
                    if mar < 0.30 and smile_ratio < 0.42:
                        return False, f"Liveness check failed: Smile not detected (MAR {mar:.2f}, ratio {smile_ratio:.2f})."
                    return True, f"Smile check passed (MAR: {mar:.2f}, Smile ratio: {smile_ratio:.2f})."
                    
                elif challenge_type == "turn_left_right":
                    # --- HEAD POSE YAW TRACKING ---
                    # Calculated by comparing the horizontal distance from the nose tip (1) 
                    # to the left and right cheek borders (234, 454).
                    nose = landmarks[1]
                    left_cheek = landmarks[234]
                    right_cheek = landmarks[454]
                    
                    left_dist = abs(nose.x - left_cheek.x)
                    right_dist = abs(nose.x - right_cheek.x)
                    ratio = left_dist / right_dist if right_dist > 0 else 1.0
                    
                    # If ratio is close to 1.0, head is centered. If skewed, head is turned.
                    if 0.65 <= ratio <= 1.54:
                        return False, f"Liveness check failed: Head turn left/right not detected (Yaw ratio {ratio:.2f})."
                    return True, f"Head turn check passed (Yaw ratio: {ratio:.2f})."
                    
                elif challenge_type == "look_up_down":
                    # --- HEAD POSE PITCH TRACKING ---
                    # Vertical distance from nose tip (1) to forehead (10) vs chin (152)
                    nose = landmarks[1]
                    forehead = landmarks[10]
                    chin = landmarks[152]
                    
                    top_dist = abs(nose.y - forehead.y)
                    bottom_dist = abs(nose.y - chin.y)
                    ratio = top_dist / bottom_dist if bottom_dist > 0 else 1.0
                    
                    if 0.65 <= ratio <= 1.55:
                        return False, f"Liveness check failed: Look up/down not detected (Pitch ratio {ratio:.2f})."
                    return True, f"Look up/down check passed (Pitch ratio: {ratio:.2f})."
                    
                else:
                    # General verification (e.g. for photo registration)
                    # We just require that landmarks are successfully located
                    return True, "Liveness checks passed (Native MediaPipe)."
            except Exception as e:
                logger.warning(f"Error during native MediaPipe liveness check: {str(e)}. Using simulation.")
        
        # --- SIMULATION FALLBACK ---
        # Validate that the frame contains a non-empty, non-dark image
        if image_matrix is not None and hasattr(image_matrix, "size") and image_matrix.size > 0:
            mean_val = float(image_matrix.mean())
            std_val = float(image_matrix.std())
            if mean_val < 12.0 or std_val < 4.0:
                return False, "No face detected in the frame. The camera image is too dark, covered, or empty."

        if challenge_type == "blink":
            if not blink_simulated:
                return False, "Liveness check failed: Eye blink not detected (Simulated)."
            return True, "Blink check passed (Simulation Mode)."
        elif challenge_type == "smile":
            if not smile_simulated:
                return False, "Liveness check failed: Smile verification failed (Simulated)."
            return True, "Smile check passed (Simulation Mode)."
        elif challenge_type == "turn_left_right":
            if not yaw_simulated:
                return False, "Liveness check failed: Head movement turn not detected (Simulated)."
            return True, "Head turn check passed (Simulation Mode)."
        elif challenge_type == "look_up_down":
            if not pitch_simulated:
                return False, "Liveness check failed: Look up/down movement not detected (Simulated)."
            return True, "Look up/down check passed (Simulation Mode)."
        else:
            # Fallback for registration / default verify without a specific challenge type
            if not blink_simulated:
                return False, "Liveness check failed: Eye blink not detected."
            if not yaw_simulated:
                return False, "Liveness check failed: Head movement turn not detected."
            if not smile_simulated:
                return False, "Liveness check failed: Smile verification failed."
            return True, "Liveness checks passed (Simulation Mode)."
