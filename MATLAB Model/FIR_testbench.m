clear;
clc;

N = 64;
number_generated = 10000;

% Generate random input data and coefficients (out of 16 bits, we will handle it on the backend)
% The Q1.15 is just a 16 bit 
inputX = int16(randi([-32768, 32767], 1, number_generated)); 
inputCoef = int16(randi([-32768, 32767], 1, N));




% Running FIR Filter
outputY = FIR_function(inputX, inputCoef);


%% -------------------------------------------------------
% Convert I/O to real values for (IS A 16b 2's complement now) producing the files for inputs and outputs

inputX_real = double(inputX) / 2^15; %Equivalent to shifting
inputCoef_real = double(inputCoef) / 2^15; 
outputY_real = double(outputY) / 2^9; 

% Write real values, one per line
fid = fopen('InputX_Real.txt', 'w');
fprintf(fid, '%.10f\n', inputX_real);    % 6 decimal places
fclose(fid);

fid = fopen('InputCoef_Real.txt', 'w');
fprintf(fid, '%.10f\n', inputCoef_real);
fclose(fid);

fid = fopen('OutputY_Real.txt', 'w');
fprintf(fid, '%.10f\n', outputY_real);
fclose(fid);

disp('DONE(real version)!')

%% -------------------------------------------------------
% Convert signed 16-bit integers to 16-bit binary strings
toBin16 = @(x) dec2bin(typecast(int16(x),'uint16'), 16);


inputX_bin   = arrayfun(toBin16, inputX,   'UniformOutput', false);
inputCoef_bin = arrayfun(toBin16, inputCoef,'UniformOutput', false);
outputY_bin  = arrayfun(toBin16, outputY,  'UniformOutput', false);

% Write BINARY FILES (each line is a 16-bit 2's complement value)

fid = fopen('InputX_Binary.txt', 'w');
fprintf(fid, '%s\n', inputX_bin{:});
fclose(fid);

fid = fopen('InputCoef_Binary.txt', 'w');
fprintf(fid, '%s\n', inputCoef_bin{:});
fclose(fid);

fid = fopen('OutputY_Binary.txt', 'w');
fprintf(fid, '%s\n', outputY_bin{:});
fclose(fid);

disp('DONE (binary version)!');