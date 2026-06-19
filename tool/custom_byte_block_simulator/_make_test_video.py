import cv2, numpy as np
w, h, fps, secs = 640, 480, 30, 6
out = cv2.VideoWriter("_test_input.mp4", cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
for i in range(fps*secs):
    frame = np.full((h, w, 3), 30, np.uint8)
    x = int((i / (fps*secs)) * (w-80))
    cv2.rectangle(frame, (x, h//2-40), (x+80, h//2+40), (0,200,255), -1)
    cv2.putText(frame, f"f{i}", (20,40), cv2.FONT_HERSHEY_SIMPLEX, 1, (255,255,255), 2)
    out.write(frame)
out.release(); print("wrote _test_input.mp4")
