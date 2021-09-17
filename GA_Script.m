clear; clc; close all;

global curv1_target curv2_target curv3_target


%% System setup
% (Make sure Solidworks is the default software for opening the SLDPRT files)


% Solidworks path
path_sld = 'C:\Program Files\SOLIDWORKS Corp\SOLIDWORKS\SLDWORKS';

% Path of the model to be optimized
path_model = 'C:\Users\maksg\Google Drive\Macbook Backup\Learning\HYPED\Test_Shell.SLDPRT';

% Path of the script to send a keystroke to Solidworks
path_keystroke_script = 'C:\Users\maksg\Google Drive\Macbook Backup\Learning\HYPED\shell-optimisation-20-21\keystroke_script.ps1';
keystroke_cmd = strjoin({'powershell -ExecutionPolicy Unrestricted -inputformat none -file "', path_keystroke_script, '"'}, "");


% Command to open load the model only if Solidworks is not open already
%command = strjoin({'tasklist /nh /fi "imagename eq SLDWORKS.exe" | find /i "SLDWORKS.exe" > nul ||("', path_model, '")'}, "");
%system(command)
% BUT IT SEEMS THAT IT DOESN'T SPEND TIME RELOADING THE FILE IF IT IS OPEN
% ANYWAY, HENCE THIS COMMAND IS SUFFICIENT:
system(path_model);

% Close Solidworks (model will need to be reopened to update from the design table)
system("taskkill /IM SLDWORKS.exe");
system('powershell -ExecutionPolicy Unrestricted -inputformat none -file keystroke_script.ps1');

% NOT WORKING - try to write the psh command directly instead of having an
% external file
%system('powershell -Command $myshell = New-Object -com "Wscript.Shell";$myshell.sendkeys("{ENTER}")')

% NOT WORKING - Run the SLD macro (will delete later)
% path_macro = 'C:\Users\maksg\Google Drive\Macbook Backup\Learning\HYPED\Dinosaur_Macro.swp';
% command = strjoin({'"', path_sld, '" "\m" "', path_macro, '"'}, '');
% system(command)




%% Input params
y0 = 2; %y-coord of the top of the rectillinear chassis (y = 0 at chassis bottom edge)
z0 = 2; %z-coord of the side of the rectillinear chassis (z = 0 at centerline)
G = 5; % max no. of generations
precision = 2; % no. of d.p. of coords

convergence_conditions = 5; %for now should be just no. of generations
P = 2; %even no. of parents chosen from prevs generation
C = 1; %no. of children for each subgroup
c_rate = 1 / 3; %crossover rate (inverse should be an inteeger)
m_rate = 1 / 5; %mutation rate (inverse should be an inteeger)


% Dummy variable to define minimum drag shape
% CFD will evaluate "closeness" to this shape for now
curv1_target = [1.1*y0; 1.15*y0; 1.1*y0];
curv2_target = [1.05*y0; 1.1*y0; 1.05*y0];
curv3_target = [1.15*z0; 1.3*z0; 1.15*z0];

%% Setting initial values of L x 3 curve matrices
% XYZ coords are the columns, pt. indices are the rows
% L is the no. of pts on the curves. L = 5 for now, pts 1 & 5 remain fixed

curv1_ini = [...
1, 0, 0;...
2, y0, 0;...
2.5, 1.25*y0, 0;...
4, y0, 0;...
5, 0, 0]; %top curve, Y-coord DoF

curv2_ini = [...
1, 0, 0;...
2, y0, z0;...
2.5, 1.25*y0, 1.25*z0;...
4, y0, z0;...
5, 0, 0]; %"diagonal" curve, Y-coord DoF, Z-coord specified by linear eqn

curv3_ini = [...
1, 0, 0;...
2, 0, z0;...
2.5, 0, 1.25*z0;...
4, 0, z0;...
5, 0, 0]; %bottom curve, Z-coord DoF


%% Create "zeroth" (initial) generation
% Done by random mutation of initial curves
% Array concatenation, datasets stored as L x 3G matrices
% G is the no. of members of the zeroth generation


% Maximum limits for mutation
y_max = 1.35 * y0;
z_max = 1.25 * z0;


%%REMEMBER TO UPDATE TUBE PHYSICAL SIZE
if y_max >= 3
	fprintf("The y-limit exceeds the physical size of the tube (+ clearance)!")
elseif z_max >= 3
	fprintf("The z-limit exceeds the physical size of the tube (+ clearance)!")
end

curv1_YBOUND = [y0, y_max];
curv2_YBOUND = [y0, y_max]; %can manually adjust if want it to be smaller than the curv1 bound
curv3_ZBOUND = [z0, z_max];



% Initialize matrices that store the generation's data, store the initial case
curv1 = [curv1_ini];
curv2 = [curv2_ini];
curv3 = [curv3_ini];

a = (curv2_ini(2, 3) -  curv2_ini(1, 3)) / (curv2_ini(2, 2) -  curv2_ini(1, 2)); %slope
b = curv2_ini(1, 3); %Z-offset, should be 0


for i = 1 : G - 1
	curv1_new = curv1_ini;
	curv2_new = curv2_ini;
	curv3_new = curv3_ini;

	for j = 2 : 4 %first and last pts remain fixed
		curv1_new(j, 2) = round(curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand(), precision);
		curv2_new(j, 2) = round(curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand(), precision);
		curv2_new(j, 3) = round(a * curv2_new(j, 2) + b, precision);
		curv3_new(j, 3) = round(curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand(), precision);
	end

	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];
end


%% Evaluate fitness

% Initialize fitness testing array
fitness_history = []; %will store the best result from each generation
fitness_gen = []; %will store the results from this generation

for i = 1 : 3 : 3*G
	curv1_temp = curv1(:, i:i+2);
	curv2_temp = curv2(:, i:i+2);
	curv3_temp = curv3(:, i:i+2);
	save_to_CSV('coords1.csv', curv1_temp);
	save_to_CSV('coords2.csv', curv2_temp);
	save_to_CSV('coords3.csv', curv3_temp);

	write_to_TXT('status.txt', "WORKING");
	run_solidworks_macro(); %will update status.txt once done

	if fileread('status.txt') == "DONE"
		run_COMSOL_CFD();
		save_COMSOL_results('result.csv');
		result = read_CSV('result.csv');

		tag = "I";
		fitness_gen = [fitness_gen, [result; tag]];
	end
end


[temp, fitness_gen_index] = sort(fitness_gen(1, :));
fitness_gen = fitness_gen(:, fitness_gen_index);
fitness_history = [fitness_history, fitness_gen(:, 1)];



%% ACTUAL GA

generation = 0;


if mod(P, 2) ~= 0
	fprintf("ERROR: P is not even!")
end

% Repeat until convergence reached
while generation ~= convergence_conditions
	generation = generation + 1;

	% Choose P best parents
	curv1_parents = [];
	curv2_parents = [];
	curv3_parents = [];

    
	for i = 1 : P
		curv1_parents = [curv1_parents, curv1(:, 3*fitness_gen_index(i)-2 : 3*fitness_gen_index(i))];
		curv2_parents = [curv2_parents, curv2(:, 3*fitness_gen_index(i)-2 : 3*fitness_gen_index(i))];
		curv3_parents = [curv3_parents, curv3(:, 3*fitness_gen_index(i)-2 : 3*fitness_gen_index(i))];
    end

	% Reset the generation dataset to include the parent subgroup
	curv1 = [curv1_parents];
	curv2 = [curv2_parents];
	curv3 = [curv3_parents];

	% To prevent overriding the parents
	curv1_parents_temp = curv1_parents;
	curv2_parents_temp = curv2_parents;
	curv3_parents_temp = curv3_parents;

	% Create crossover subgroup
	for i = 2 : 4
		for j = 1 : 6 : 3*P
			crand1 = randi(1 / c_rate);
			crand2 = randi(1 / c_rate);
			crand3 = randi(1 / c_rate);

			if crand1 == 1
				temp = curv1_parents_temp(i, j:j+2);
				curv1_parents_temp(i, j:j+2) = curv1_parents_temp(i, j+3:j+5);
				curv1_parents_temp(i, j+3:j+5) = temp;
			end

			if crand2 == 1
				temp = curv2_parents_temp(i, j:j+2);
				curv2_parents_temp(i, j:j+2) = curv2_parents_temp(i, j+3:j+5);
				curv2_parents_temp(i, j+3:j+5) = temp;
			end

			if crand3 == 1
				temp = curv3_parents_temp(i, j:j+2);
				curv3_parents_temp(i, j:j+2) = curv3_parents_temp(i, j+3:j+5);
				curv3_parents_temp(i, j+3:j+5) = temp;
			end

		end
	end
	curv1_new = curv1_parents_temp;
	curv2_new = curv2_parents_temp;
	curv3_new = curv3_parents_temp;

	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];






	% Create crossover + mutation subgroup
	for i = 2 : 4
		for j = 1 : 6 : 3*P
			crand1 = randi(1 / c_rate);
			crand2 = randi(1 / c_rate);
			crand3 = randi(1 / c_rate);

			if crand1 == 1
				temp = curv1_parents_temp(i, j:j+2);
				curv1_parents_temp(i, j:j+2) = curv1_parents_temp(i, j+3:j+5);
				curv1_parents_temp(i, j+3:j+5) = temp;
			end

			if crand2 == 1
				temp = curv2_parents_temp(i, j:j+2);
				curv2_parents_temp(i, j:j+2) = curv2_parents_temp(i, j+3:j+5);
				curv2_parents_temp(i, j+3:j+5) = temp;
			end

			if crand3 == 1
				temp = curv3_parents_temp(i, j:j+2);
				curv3_parents_temp(i, j:j+2) = curv3_parents_temp(i, j+3:j+5);
				curv3_parents_temp(i, j+3:j+5) = temp;
            end
        end
        
		for j = 2 : 3 : 3*P
			mrand1 = randi(1 / m_rate);
			mrand2 = randi(1 / m_rate);
            mrand3 = randi(1 / m_rate);
			if mrand1 == 1
				curv1_parents_temp(i, j) = round(curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand(), precision);
            end 
			if mrand2 == 1
				curv2_parents_temp(i, j) = round(curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand(), precision);
				curv2_parents_temp(i, j+1) = round(a * curv2_new(j, 2) + b, 2);
            end
            if mrand3 == 1
				curv3_parents_temp(i, j+1) = round(curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand(), precision);
            end   
        end
        
        

	curv1_new = curv1_parents_temp;
	curv2_new = curv2_parents_temp;
	curv3_new = curv3_parents_temp;

	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];

    end

	% Create mutation only subgroup
	for i = 2 : 4
		for j = 2 : 3 : 3*P
			mrand1 = randi(1 / m_rate);
			mrand2 = randi(1 / m_rate);
            mrand3 = randi(1 / m_rate);
			if mrand1 == 1
				curv1_parents_temp(i, j) = round(curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand(), precision);
            end
			if mrand2 == 1
				curv2_parents_temp(i, j) = round(curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand(), precision);
				curv2_parents_temp(i, j+1) = round(a * curv2_new(j, 2) + b, precision);
            end
			if mrand3 == 1
				curv3_parents_temp(i, j+1) = round(curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand(), precision);
            end
        end
	curv1_new = curv1_parents_temp;
	curv2_new = curv2_parents_temp;
	curv3_new = curv3_parents_temp;
    
    
	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];
    end


	% Fitness testing, continued
	fitness_gen = []; %will store the results from this generation

	for i = 1 : 3 : 3*(P + 3*C)
		curv1_temp = curv1(:, i:i+2);
		curv2_temp = curv2(:, i:i+2);
		curv3_temp = curv3(:, i:i+2);
		save_to_CSV('coords1.csv', curv1_temp);
		save_to_CSV('coords2.csv', curv2_temp);
		save_to_CSV('coords3.csv', curv3_temp);

		write_to_TXT('status.txt', "WORKING");
		run_solidworks_macro(); %that script will update status.txt once done

		if fileread('status.txt') == "DONE"
			run_COMSOL_CFD();
			save_COMSOL_results('result.csv')
			result = read_CSV('result.csv');
        
			if i <= 3*P-2
				tag = "P";
			elseif 3*P-2 < i && i <= 3*(P+C)-2
				tag = "C";
			elseif 3*(P+C)-2 < i && i <= 3*(P+2*C)-2
				tag = "CM";
			elseif 3*(P+2*C)-2 < i && i <= 3*(P+3*C)-2
				tag = "M";
			end

			fitness_gen = [fitness_gen, [result; tag]];
        end


        [temp, fitness_gen_index] = sort(fitness_gen(1, :));
        fitness_gen = fitness_gen(:, fitness_gen_index);
        fitness_history = [fitness_history, fitness_gen(:, 1)];
    end
end



%% Post-processing

% Print the best results & save to CSV
curv1_best = curv1(:, 3*fitness_gen_index(1)-2:3*fitness_gen_index(1))
curv2_best = curv2(:, 3*fitness_gen_index(1)-2:3*fitness_gen_index(1))
curv3_best = curv3(:, 3*fitness_gen_index(1)-2:3*fitness_gen_index(1))

save_to_CSV('coords1.csv', curv1_temp);
save_to_CSV('coords2.csv', curv2_temp);
save_to_CSV('coords3.csv', curv3_temp);

% Update CAD model
run_solidworks_macro();

% Convert the result history into numeric from strings
temp = [];
for i = 1:length(fitness_history)
    temp = [temp, str2double(fitness_history(1, i))];
end

% Plot the convergence over time
figure(1)
tiledlayout(1, 2)
nexttile
plot(1:length(fitness_history), temp)
title("Fitness over generations")
xlabel("Generation")
ylabel("Fitness score")
grid minor

% Plot the histogram
nexttile
[tag, temp, group] = unique(fitness_history(2, :));
counts = groupcounts(group)';
bar(counts)
title("No. of best results with a given tag")
xlabel("Tag")
ylabel("Frequency")
set(gca, 'xticklabel', tag)
grid

%{
==== MISSING ====

BUG WITH MUTATION SUBGROUP – sometimes the mutation changes a coordinate to
0 randomly


Current issues: need to make sure amount of mutated children is ok (currently generates 3 * P + 1, should be either P + 3 * C
(with C being appropriate given P) or 3 * P + C, although then have to choose which one to mutate)
==== MISSING =====
%}



function csv_read = read_CSV(file)
    csv_read = csvread(file);
end
    
function csv_save = save_to_CSV(file, coords)
    csvwrite(file, coords);
end

function txt = write_to_TXT(file, msg)
    txtfile = fopen(file, 'w');
    txt = fprintf(txtfile, msg);
end


%% TBD, will be based on a terminal command to execute the Solidworks macro

function sld = run_solidworks_macro()
    % Delete this bit later
    txtfile = fopen('status.txt', 'w');
    fprintf(txtfile, "DONE");
    
	%sld = fprintf("Run Solidworks macro function not finished!\n\n");
end

%% TBD Matlab Livelink

% For now dummy fn that returns a result based on how close to dummy target
function cfd = run_COMSOL_CFD()

    global curv1_target curv2_target curv3_target
    
    curv1_dummy = csvread('coords1.csv');
    curv2_dummy = csvread('coords2.csv');
    curv3_dummy = csvread('coords3.csv');
    
    curv1_score = abs(curv1_dummy(2:4, 2) - curv1_target);
    curv2_score = abs(curv2_dummy(2:4, 2) - curv2_target);
    curv3_score = abs(curv3_dummy(2:4, 3) - curv3_target);
    dummy_score = sum(curv1_score) + sum(curv2_score) + sum(curv3_score);

    save_to_CSV('result.csv', dummy_score)
      

	%cfd = fprintf("Run COMSOL sim function not finished!\n\n");
end

% For now saves the dummy array from run_COMSOL_CFD
function cfd_res = save_COMSOL_results(file)
    % Dummy result, currently replaced with the run_COMSOL_CFD dummy
    % function
    %dummy_result = 400 + 100 * rand();
    %save_to_CSV(file, dummy_result)
    
	%cfd_res = fprintf("Save COMSOL results function not finished!\n\n");
end


