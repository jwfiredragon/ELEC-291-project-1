import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math,serial

ser = serial.Serial(
    port='COM8',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()
xsize=100
reflow_temp=40

soak_temp=10
soak_time=60

str= "REFLOW OVEN";

print ('To stop press Ctrl+C')

   
def data_gen():
    #reflow_temp=ser.readline()
    #soak_temp=ser.readline()
    #reflow_time=ser.readline()
    t = data_gen.t
    while True:
       strin = ser.readline()
       t+=1
       #val=100.0*math.sin(t*2.0*3.1415/100.0)
       val=int(strin.decode())
       yield t, val

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        #ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        if y>reflow_temp:
            flag=1
            xdata5.append(t)
            ydata5.append(y)           
            line5.set_data(xdata5, ydata5)
            line5.set_color('red')
            return line5,
        # elif flag==1:
        #     xdata1.append(t)
        #     ydata1.append(y)           
        #     line1.set_data(xdata1, ydata1)
        #     line1.set_color('red')
        #     return line1,
        elif y>soak_temp:
            xdata4.append(t)
            ydata4.append(y)
            line4.set_data(xdata4, ydata4)
            line4.set_color('blue')
            return line4
        elif(y>soak_temp-20 and t>45):
            xdata3.append(t)
            ydata3.append(y)
            line3.set_data(xdata3, ydata3)
            line3.set_color('black')
            return line3,
        else:
            xdata2.append(t)
            ydata2.append(y)
            line2.set_data(xdata2,ydata2)
            line2.set_color('green')
            return line2


def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1


fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
plt.title('ReFlow Oven temprature')
plt.xlabel('Time')
plt.ylabel('Temprature')
ax = fig.add_subplot(111)
line1, = ax.plot([], [], lw=2)
line2, = ax.plot([], [], lw=2)
line3, = ax.plot([], [], lw=2)
line4, = ax.plot([], [], lw=2)
line5, = ax.plot([], [], lw=2)
ax.set_ylim(10, 300)
ax.set_xlim(0, xsize)
ax.grid()
xdata5, ydata5,xdata4, ydata4,xdata,xdata3, ydata3,xdata1,ydata1,xdata2,ydata2 = [], [],[], [],[], [], [], [], [], [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()
