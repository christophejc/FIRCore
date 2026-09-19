function outputY = FIR_function(inputX, inputCoef)
% FIR_FUNCTION - 64-bit accumulator, shift THEN saturation
% inputX       : Q1.15 signed input samples
% inputCoef    : Q1.15 signed coefficients
% outputY      : Q7.9 signed output

N = 64;
if length(inputCoef) ~= N
    error("Coefficient length must match N.");
end

x_len = length(inputX);
outputY = int16(zeros(1, x_len));

for n = 1:x_len
    currSum64 = int64(0);  % 64-bit accumulator
    
    for k = 1:N
        if n-k+1 > 0
            % Inputs are 16-bit, Products are 32-bit
            x_val = int32(inputX(n-k+1));
            c_val = int32(inputCoef(k));
            
            % --- Sign-Magnitude Multiplication Logic (Matches your HW) ---
            x_abs = uint64(abs(x_val));
            c_abs = uint64(abs(c_val));
            prod_abs = x_abs * c_abs;
            
            sign_bit = bitxor(bitshift(x_val, -31), bitshift(c_val, -31));
            
            if sign_bit
                currSum64 = currSum64 - int64(prod_abs);
            else
                currSum64 = currSum64 + int64(prod_abs);
            end
        end
    end
    
    % --- CRITICAL FIX HERE ---
    % Do NOT wrap to 32 bits here. Use the full 64-bit sum for the shift.
    
    % 1. Arithmetic Shift Right by 21 (Q2.30 -> Q7.9)
    shiftedSum = bitshift(currSum64, -21);
    
    % 2. Saturate to 16-bit Signed Range (-32768 to +32767)
    if shiftedSum > 32767
        outputY(n) = 32767;
    elseif shiftedSum < -32768
        outputY(n) = -32768;
    else
        outputY(n) = int16(shiftedSum);
    end
end
end