#!/usr/bin/env python3
import time, os, math, pygame

pygame.init()
pygame.joystick.init()

count = pygame.joystick.get_count()
if count == 0:
    print("❌ No controllers detected.")
    exit(1)

print("🎮 Available controllers:")
for i in range(count):
    j = pygame.joystick.Joystick(i)
    j.init()
    print(f"  [{i}] {j.get_name()} ({j.get_numaxes()} axes, {j.get_numbuttons()} buttons)")

index = input("\nSelect controller index to test: ")
try:
    idx = int(index)
    js = pygame.joystick.Joystick(idx)
except Exception:
    print("Invalid index.")
    exit(1)

print(f"\n✅ Testing: {js.get_name()}")
print("Press any button repeatedly for ~5 seconds... (Ctrl+C to stop)\n")

timestamps = []
try:
    while True:
        pygame.event.pump()
        for i in range(js.get_numbuttons()):
            if js.get_button(i):
                t = time.time()
                timestamps.append(t)
                print(f"Button {i} pressed at {t:.6f}")
        time.sleep(0.001)
except KeyboardInterrupt:
    pass

if len(timestamps) < 2:
    print("\nNot enough data collected.")
    exit(0)

# --- Calculate latency statistics ---
intervals = [timestamps[i+1] - timestamps[i] for i in range(len(timestamps)-1)]
avg_interval = sum(intervals)/len(intervals)
polling_rate = 1.0 / avg_interval
variance = sum((x - avg_interval) ** 2 for x in intervals) / len(intervals)
stdev = math.sqrt(variance)
stdev_ms = stdev * 1000

# --- Log result ---
log_path = "/userdata/system/logs/input_latency.txt"
os.makedirs(os.path.dirname(log_path), exist_ok=True)
entry = (
    f"{time.ctime()}: {js.get_name()} ({idx}) - "
    f"{polling_rate:.1f} Hz avg interval {avg_interval*1000:.2f} ms "
    f"(±{stdev_ms:.2f} ms stdev)"
)
print(f"\n{entry}")
with open(log_path, "a") as f:
    f.write(entry + "\n")

# --- Compare to previous test ---
try:
    with open(log_path, "r") as f:
        lines = [l.strip() for l in f.readlines() if "Hz avg interval" in l]
    if len(lines) >= 2:
        last = lines[-2]
        prev_rate = float(last.split(" - ")[1].split(" ")[0])
        prev_name = last.split(": ")[1].split(" (")[0]
        diff = ((polling_rate - prev_rate) / prev_rate) * 100
        faster = "faster" if diff > 0 else "slower"
        print(f"\n📊 Compared to previous test ({prev_name}):")
        print(f"    {js.get_name()} is {abs(diff):.1f}% {faster} ({polling_rate:.1f} Hz vs {prev_rate:.1f} Hz).")
    else:
        print("\n📊 Not enough previous data to compare.")
except Exception as e:
    print(f"\n⚠️ Could not compare results: {e}")

print(f"\n✅ Results logged to {log_path}")