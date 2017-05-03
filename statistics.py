#!/usr/bin/python

import serial
import sys
import re
import time
import threading
from collections import defaultdict
from collections import Counter

basetime_time = time.time()

def basetime():
	return str(int(time.time()-basetime_time))

def avg(list):
	sum = 0
	if list and len(list) > 0:
		for e in list:
			sum += e
		return sum/float(len(list))
	else:
		return -1.0

def most_common_mode(lst):
	if lst:
		counter = Counter(lst)
		return counter.most_common(1)[0][0]
	else:
		return -1

class ReadThread(threading.Thread):
	def match_line(self, line):
		#todo do parsing outside lock
		kpi_lock.acquire(True)
		match = re.search('\^RSSI: ([0-9]+)', line)
		if match:
			kpi['uns_rssi'].append(int(match.group(1)))
		match = re.search('\^MODE: ([0-9]+),([0-9]+)', line)
		if match:
			kpi['uns_mode'].append(int(match.group(1)))
			kpi['uns_submode'].append(int(match.group(2)))
		match = re.search('\^SYSINFOEX:(.*)', line)
		if match:
			sysinfoex = match.group(1).split(',')
			kpi['mode'].append(float(sysinfoex[7])+float(sysinfoex[5])/10.0)
		match = re.search('\^ANQUERY:(.*)', line)
		if match:
			anquery = match.group(1).split(',')
			kpi['rscp'].append(int(anquery[0]))
			kpi['ecio'].append(int(anquery[1]))
			kpi['rssi'].append(int(anquery[2]))
			kpi['alevel'].append(int(anquery[3]))
			kpi['cellid'] = anquery[4]
		kpi_lock.release()

	def run(self):
		while 1:
			line = con.readline()
		#	print basetime() + "----------RAW----------------> found %d \\rs" % line.count("\r")
		#	print basetime() + "----------RAW----------------> found %d \\ns" % line.count("\n")
		#	print(basetime() + "----------RAW---------------->" + line)
			self.match_line(line)

		#	print basetime() + " " + str(kpi)

	def __init__(self, console, kpi, kpi_lock):
		self.con = console
		self.kpi = kpi
		self.kpi_lock = kpi_lock
		threading.Thread.__init__(self)
		threading.Thread.daemon = True
		self.start()

tty_name = sys.argv[1]
print "using tty " + tty_name
kpi = defaultdict(list)
kpi_lock = threading.Lock()

con = serial.Serial(
	port=tty_name,
	baudrate=115200,
	timeout=None
)
con.isOpen()

read_thread = ReadThread(con, kpi, kpi_lock)

#allow read thread to startup. No guarantees of course, but that is fine.
#Worst case we will miss a value, but this is a slow averaging process
time.sleep(2)

filename = "/tmp/3g_kpi_" + time.strftime("%Y-%m-%d_%H-%M-%S") + ".csv"
print "saving to file " + filename

f = open (filename, 'a', buffering = 1)
f.write("#file " + filename + "\n")
f.write("#each line is averaged of 10samples, between each sample is 30s\n")
f.write("#rssi, rscp, alevel, ecio, mode, date (yyyy-MM-dd HH:mm:ss)\n")

try:
	while True:
		#sample every 30s, calculate average (and write to file) every 30s*10=5min
		for i in xrange(0,10):
			con.write("AT^ANQUERY?\r")
			time.sleep(1)
			con.write("AT^SYSINFOEX\r")
			time.sleep(29)
#			print basetime() + " sending " + str(i) + " " + str(kpi)
		time.sleep(2)

		kpi_lock.acquire(True)
		rssi   = avg(kpi['rssi'] + kpi['uns_rssi'])
		rscp   = avg(kpi['rscp'])
		alevel = avg(kpi['alevel']) 
		ecio   = avg(kpi['ecio'])
		mode   = most_common_mode(kpi['mode']) 
		kpi.clear()
		kpi_lock.release()
	
		string = "%.1f, %.1f, %.1f, %.1f, %.1f, " % \
			(rssi, rscp, alevel, ecio, mode) + \
			time.strftime("%Y-%m-%d %H:%M:%S") + "\n"
		f.write(string)
		print("rssi, rscp, alevel, ecio, mode, date")
		print(string)
except KeyboardInterrupt:
	print "caught ctrl+c"
con.close()
f.close()
