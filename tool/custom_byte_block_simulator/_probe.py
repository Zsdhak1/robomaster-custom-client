import time
import paho.mqtt.client as mqtt
import robomaster_custom_client_pb2 as rm
n=0; b=0; sps=False
def has_sps(d):
    for i in range(len(d)-4):
        if d[i]==0 and d[i+1]==0 and d[i+2]==0 and d[i+3]==1 and (d[i+4]&0x1F)==7: return True
        if d[i]==0 and d[i+1]==0 and d[i+2]==1 and (d[i+3]&0x1F)==7: return True
    return False
def on_msg(c,u,m):
    global n,b,sps
    blk=rm.CustomByteBlock(); blk.ParseFromString(m.payload); d=bytes(blk.data)
    n+=1; b+=len(d)
    if not sps and has_sps(d): sps=True
s=mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2,client_id="probe")
s.on_message=on_msg; s.connect("127.0.0.1",3333,60); s.subscribe("CustomByteBlock",0); s.loop_start()
time.sleep(5)
print(f"PROBE result: packets={n} bytes={b} sps_seen={sps}")
s.loop_stop()
