import sys

# ==========================================
# CONFIGURATION
# ==========================================
# Make sure these file names match exactly what is on your disk
INPUT_X_FILE = "InputX_Binary.txt"
INPUT_COEF_FILE = "InputCoef_Binary.txt"
OUTPUT_Y_FILE = "OutputY_Ref.txt"

SHIFT_AMOUNT = 21

# ==========================================
# HELPER FUNCTIONS
# ==========================================
def to_signed_16(hex_str):
    """
    Converts a 16-bit binary string (e.g., '1111111111111111') 
    to a signed Python integer (e.g., -1).
    """
    val = int(hex_str, 2)
    # If the MSB (bit 15) is 1, it's a negative number in 16-bit 2's complement
    if val & 0x8000:
        return val - 0x10000
    return val

def to_binary_16(val):
    """Converts int to 16-bit 2's complement binary string."""
    return f"{(val & 0xFFFF):016b}"

def saturate_16(val):
    """
    Saturates a value to the 16-bit signed range [-32768, 32767].
    Matches the logic in your Matlab and Verilog fix.
    """
    if val > 32767:
        return 32767
    elif val < -32768:
        return -32768
    return val

# ==========================================
# 1. READ INPUT FILES
# ==========================================
print(f"Reading inputs from {INPUT_X_FILE} and {INPUT_COEF_FILE}...")

try:
    with open(INPUT_X_FILE, 'r') as f:
        # Read lines, strip whitespace, filter out empty lines
        lines = [l.strip() for l in f.readlines() if l.strip()]
        input_x = [to_signed_16(l) for l in lines]

    with open(INPUT_COEF_FILE, 'r') as f:
        lines = [l.strip() for l in f.readlines() if l.strip()]
        coeffs = [to_signed_16(l) for l in lines]

except FileNotFoundError as e:
    print(f"Error: {e}")
    print("Please make sure the input text files are in the same directory.")
    sys.exit(1)

NUM_SAMPLES = len(input_x)
N_TAPS = len(coeffs)

print(f"Loaded {NUM_SAMPLES} samples and {N_TAPS} coefficients.")

# ==========================================
# 2. RUN FIR FILTER (BIT-EXACT MODEL)
# ==========================================
output_y = []

print("Running FIR Model...")

for n in range(NUM_SAMPLES):
    # We use a large python integer for the accumulator, so we don't need
    # to mask it to 32-bits manually until the very end if we want wrap behavior.
    # However, standard FIR accumulation is usually clean math until the shift.
    curr_sum = 0
    
    # Convolution Loop
    for k in range(N_TAPS):
        # Determine index of input x[n-k]
        idx = n - k 
        
        if idx >= 0:
            x_val = input_x[idx]
            c_val = coeffs[k]
            
            # Multiply and Accumulate
            curr_sum += (x_val * c_val)

    # 3. Arithmetic Shift Right (>>> 21)
    # Python's >> is arithmetic for signed integers
    shifted_sum = curr_sum >> SHIFT_AMOUNT
    
    # 4. Saturate (Clip to 16-bit signed range)
    final_out = saturate_16(shifted_sum)
    
    output_y.append(final_out)

    # Optional: Debug Print first few samples
    if n < 5:
        print(f"Sample {n}: Sum={curr_sum} -> Shifted={shifted_sum} -> Sat={final_out} ({to_binary_16(final_out)})")

# ==========================================
# 3. WRITE OUTPUT FILE
# ==========================================
with open(OUTPUT_Y_FILE, 'w') as f:
    for val in output_y:
        f.write(to_binary_16(val) + '\n')

print(f"\nDONE! Generated {OUTPUT_Y_FILE}")