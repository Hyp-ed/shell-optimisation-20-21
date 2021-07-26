clear; clc; close all;


%% Setting initial values of L x 3 curve matrices
% XYZ coords are the columns, pt. indices are the rows
% L is the no. of pts on the curves. L = 5 for now, pts 1 & 5 remain fixed


y0 = 2 %y-coord of the top of the rectillinear chassis (y = 0 at chassis bottom edge)
z0 = 2 %z-coord of the side of the rectillinear chassis (z = 0 at centerline)


curv1_ini = [...
1, 0, 0;...
2, y0, 0;...
2.5, 1.25*y0, 0;...
4, y0, 0;...
5, 0, 0]; %top curve, Y-coord DoF

curv2_ini = [...
1, 0, 0;...
2, 0, z0;...
2.5, 0, 1.25*z0;...
4, 0, z0;...
5, 0, 0]; %"diagonal" curve, Y-coord DoF, Z-coord specified by linear eqn

curv3_ini = [...
1, 0, 0;...
2, y0, z0;...
2.5, 1.25*y0, 1.25*z0;...
4, y0, z0;...
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

G = 5


for i = 1 : G - 1
	curv1_new = curv1_ini;
	curv2_new = curv2_ini;
	curv3_new = curv3_ini;

	for j = 2 : 4 %first and last pts remain fixed
		curv1_new(j, 2) = curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand();
		curv2_new(j, 2) = curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand();
		curv2_new(j, 3) = a * curv2_new(j, 2) + b;
		curv3_new(j, 3) = curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand();
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
	save_to_CSV(coords.csv, curv1_temp)
	save_to_CSV(coords.csv, curv2_temp)
	save_to_CSV(coords.csv, curv3_temp)

	write_to_TXT(status.txt, "WORKING")
	run_solidworks_macro() %will update status.txt once done

	if fileread('status.txt') == "DONE"
		run_COMSOL_CFD()
		save_COMSOL_results('result.csv')
		result = read_csv('result.csv');

		tag = "I";
		fitness_gen = [fitness_gen, [result; tag]];
	end
end


[fitness_gen, fitnesss_gen_index] = sort(fitness_gen, 'descend');
fitness_history = [fitness_history, fitness_gen(:, 1)];



%% ACTUAL GA

convergence_conditions = 5; %for now should be just no. of generations
generation = 0;

P = 2; %even no. of parents chosen from prevs generation
c_rate = 1 / 3; %crossover rate (inverse should be an inteeger)
m_rate = 1 / 5; %mutation rate (inverse should be an inteeger)

if mod(P, 2) ~= 0
	fprintf("ERROR: P is not even!")
end

C = 1; %no. of children for each subgroup


% Repeat until convergence reached
while generation ~= convergence_conditions
	generation = generation + 1;

	% Choose P best parents
	curv1_parents = [];
	curv2_parents = [];
	curv3_parents = [];

	for i = 1 to P
		curv1_parents = [curv1_parents, curv1(:, 3*fitness_gen_index(i))];
		curv2_parents = [curv2_parents, curv2(:, 3*fitness_gen_index(i))]];
		curv3_parents = [curv3_parents, curv3(:, 3*fitness_gen_index(i))]];
	end

	% Reset the generation dataset to include the parent subgroup
	curv1 = [curv1_parents];
	curv2 = [curv2_parents];
	curv3 = [curv3_parents];

	% To prevent overriding the parents
	curv1_parents_temp = curv1_parents
	curv2_parents_temp = curv2_parents
	curv3_parents_temp = curv3_parents

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
	for i = 2 to 4
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

		for j = 2 : 3 : 3*P
			mrand1 = randi(1 / m_rate);
			mrand2 = randi(1 / m_rate);

			if mrand1 == 1
				curv1_parents_temp(j, 2) = curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand();

			if mrand2 == 1
				curv2_parents_temp(j, 2) = curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand();
				curv2_parents_temp(j, 3) = a * curv2_new(j, 2) + b;

		for j = 3 : 3 : 3*P
			mrand3 = randi(1 / m_rate);

			if mrand3 == 1
				curv3_parents_temp(j, 3) = curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand();

	curv1_new = curv1_parents_temp;
	curv2_new = curv2_parents_temp;
	curv3_new = curv3_parents_temp;

	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];


	% Create mutation only subgroup
	for i = 2 to 4
		for j = 2 : 3 : 3*P
			mrand1 = randi(1 / m_rate);
			mrand2 = randi(1 / m_rate);

			if mrand1 == 1
				curv1_parents_temp(j, 2) = curv1_YBOUND(1) + (curv1_YBOUND(2) - curv1_YBOUND(1)) * rand();

			if mrand2 == 1
				curv2_parents_temp(j, 2) = curv2_YBOUND(1) + (curv2_YBOUND(2) - curv2_YBOUND(1)) * rand();
				curv2_parents_temp(j, 3) = a * curv2_new(j, 2) + b;

		for j = 3 : 3 : 3*P
			mrand3 = randi(1 / m_rate);

			if mrand3 == 1
				curv3_parents_temp(j, 3) = curv3_ZBOUND(1) + (curv3_ZBOUND(2) - curv3_ZBOUND(1)) * rand();


	curv1_new = curv1_parents_temp;
	curv2_new = curv2_parents_temp;
	curv3_new = curv3_parents_temp;

	curv1 = [curv1, curv1_new];
	curv2 = [curv2, curv2_new];
	curv3 = [curv3, curv3_new];



	% Fitness testing, continued
	fitness_gen = []; %will store the results from this generation

	for i = 1 : 3 : 3*(P + 3*C)
		curv1_temp = curv1[:, i:i+2];
		curv2_temp = curv2[:, i:i+2];
		curv3_temp = curv3[:, i:i+2];
		save_to_CSV(coords.csv, curv1_temp)
		save_to_CSV(coords.csv, curv2_temp)
		save_to_CSV(coords.csv, curv3_temp)

		write_to_TXT('status.txt', "WORKING")
		run_solidworks_macro() %that script will update status.txt once done

		if fileread('status.txt') == "DONE"
			run_COMSOL_CFD()
			save_COMSOL_results('result.csv')
			result = read_csv('result.csv')

			if i <= P
				tag = "P";
			elseif P < i < P + C
				tag = "C";
			elseif P + C < i <= P + 2*C
				tag = "CM";
			elseif P + 2*C < i <= P + 3*C
				tag = "M";
			end

			fitness_gen = [fitness_gen, [result; tag]];
		end



	[temp, order] = sort(fitness_gen, 'descend');
	fitness_gen = fitness_gen(:, order);
	fitness_history = [fitness_history, fitness_gen(:, 1)];

	end
end



%{
==== MISSING ====
At the end, print the best results / store them as a variable and also update the CAD model with them (by running the macro)
and also plot the convergence over generations


Current issues: need to make sure amount of mutated children is ok (currently generates 3 * P + 1, should be either P + 3 * C
(with C being appropriate given P) or 3 * P + C, although then have to choose which one to mutate)
==== MISSING =====
%}




function csv_read = read_csv(file)
	csv_read = fprintf("Save to CSV function not finished!")

function csv_save = save_to_CSV(file, coords)
	csv_save = fprintf("Save to CSV function not finished!")

function txt = write_to_TXT(file, msg)
	txt = fprintf("Write to TXT function not finished!")

function sld = run_solidworks_macro()
	sld = fprintf("Run Solidworks macro function not finished!")

function cfd = run_COMSOL_CFD()
	cfd = fprintf("Run COMSOL sim function not finished!")

function cfd_res = save_COMSOL_results()
	cfd_res = fprintf("Save COMSOL results function not finished!")



