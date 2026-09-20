import sys

# ==========================================
# CONFIGURATION
# ==========================================
INPUT_X_FILE    = "InputX_Real.txt"
INPUT_COEF_FILE = "InputCoef_Real.txt"
OUTPUT_Y_FILE   = "OutputY_Python_Real.txt"

# ==========================================
# 1. READ INPUT FILES
# ==========================================
print(f"Reading real decimal inputs from {INPUT_X_FILE} and {INPUT_COEF_FILE}...")

def read_floats(filename):
    try:
        with open(filename, 'r') as f:
            # Read lines, strip whitespace, filter empty lines, convert to float
            return [float(l.strip()) for l in f.readlines() if l.strip()]
    except FileNotFoundError:
        print(f"Error: Could not find '{filename}'.")
        print("Please create this file with your decimal values (one per line).")
        sys.exit(1)
    except ValueError as e:
        print(f"Error parsing '{filename}': {e}")
        sys.exit(1)

input_x = read_floats(INPUT_X_FILE)
coeffs  = read_floats(INPUT_COEF_FILE)

NUM_SAMPLES = len(input_x)
N_TAPS = len(coeffs)

print(f"Loaded {NUM_SAMPLES} samples and {N_TAPS} coefficients.")

# ==========================================
# 2. RUN FIR FILTER (FLOATING POINT)
# ==========================================
# Logic: Standard Convolution
# y[n] = Sum( x[n-k] * h[k] )

output_y = []

print("Calculating ideal floating-point results...")

for n in range(NUM_SAMPLES):
    curr_sum = 0.0
    
    # Convolution Loop
    for k in range(N_TAPS):
        idx = n - k
        
        # Check boundary (Zero Padding logic)
        if idx >= 0:
            val_x = input_x[idx]
            val_c = coeffs[k]
            
            # Standard multiply-accumulate
            curr_sum += (val_x * val_c)

    output_y.append(curr_sum)

    # Optional: Print first few to verify
    if n < 30:
        print(f"Sample {n}: {curr_sum:.10f}")

# ==========================================
# 3. WRITE OUTPUT FILE
# ==========================================
with open(OUTPUT_Y_FILE, 'w') as f:
    for val in output_y:
        # Write with high precision (10 decimal places)
        f.write(f"{val:.10f}\n")

print(f"\nDONE! Generated {OUTPUT_Y_FILE}")