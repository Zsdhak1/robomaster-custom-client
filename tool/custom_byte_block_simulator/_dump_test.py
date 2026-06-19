import cv2, numpy as np
from fractions import Fraction
import av
W=H=400; FPS=60
codec = av.CodecContext.create("h264","w")
codec.width=W; codec.height=H; codec.pix_fmt="yuv420p"
codec.time_base=Fraction(1,FPS); codec.framerate=Fraction(FPS,1)
codec.bit_rate=80*1000; codec.gop_size=30; codec.max_b_frames=4
codec.options={"preset":"veryfast","x264opts":"repeat-headers=1:scenecut=0:force-cfr=1:annexb=1","profile":"baseline"}
out=open("_dump.h264","wb")
for i in range(150):
    frame=np.full((H,W,3),30,np.uint8)
    x=int((i/150)*(W-60)); cv2.rectangle(frame,(x,H//2-30),(x+60,H//2+30),(0,200,255),-1)
    rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB)
    vf=av.VideoFrame.from_ndarray(rgb,format="rgb24"); vf.pts=i
    for p in codec.encode(vf): out.write(bytes(p))
for p in codec.encode(): out.write(bytes(p))
out.close()
print("dumped _dump.h264")
