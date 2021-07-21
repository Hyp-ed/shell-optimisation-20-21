## Setting initial values of L x 3 curve matrices
# XYZ coords are the columns, pt. indices are the rows
# L is the no. of pts on the curves. L = 5 for now, pts 1 & 5 remain fixed

curv1_ini = [
x1, y1, z1;
x2, y2, z2;
x3, y3, z3;
x4, y4, z4;
x5, y5, z5;
] #top curve, Y-coord DoF

curv2_ini = [...] #"diagonal" curve, Y-coord DoF, Z-coord specified by linear eqn
curv3_ini = [...] #bottom curve, Z-coord DoF


## Create "zeroth" (initial) generation
# Done by random mutation of initial curves
# Array concatenation, datasets stored as L x 3G matrices
# G is the no. of members of the zeroth generation

y0 = ... #y-coord of the top of the rectillinear chassis (y = 0 at chassis bottom edge)
z0 = ... #z-coord of the side of the rectillinear chassis (z = 0 at centerline)


# Maximum limits for mutation
y_max = 1.2 * y0
z_max = 1.1 * z0

if y_max >= ...
	print("The y-limit exceeds the physical size of the tube (+ clearance)!")
elif z_max >= ...
	print("The z-limit exceeds the physical size of the tube (+ clearance)!")

curv1_YBOUND = [y0, y_max]
curv2_YBOUND = [y0, y_max] #can manually adjust if want it to be smaller than the curv1 bound
curv3_ZBOUND = [z0, z_max]


# Initialize matrices that store the generation's data, store the initial case
curv1 = [curv1_ini]
curv2 = [curv2_ini]
curv3 = [curv3_ini]

a = (curv2_ini[2, 3] -  curv2_ini[1, 3]) / (curv2_ini[2, 2] -  curv2_ini[1, 2]) #slope
b = curv2_ini[1, 3] #Z-offset, should be 0

for i = 1 to G - 1
	curv1_new = curv1_ini
	curv2_new = curv2_ini
	curv3_new = curv3_ini

	for j = 2 to 4 #first and last pts remain fixed
		curv1_new[j, 2] = random(curv1_YBOUND, decimal)
		curv2_new[j, 2] = random(curv2_YBOUND, decimal)
		curv2_new[j, 3] = a * curv2_new[j, 2] + b
		curv3_new[j, 3] = random(curv1_YBOUND, decimal)

	curv1 = concat(curv1, curv1_new)
	curv2 = concat(curv2, curv2_new)
	curv3 = concat(curv3, curv3_new)


## Evaluate fitness

# Initialize fitness testing array
fitness_history = [] #will store the best result from each generation
fitness_gen = [] #will store the results from this generation

for i = 1 : 3 : 3 * G
	curv1_temp = curv1[:, i:i+2]
	curv2_temp = curv2[:, i:i+2]
	curv3_temp = curv3[:, i:i+2]
	save_to_CSV(coords.csv, curv1_temp)
	save_to_CSV(coords.csv, curv2_temp)
	save_to_CSV(coords.csv, curv3_temp)

	write_to_TXT(status.txt, "WORKING")
	run_solidworks_macro() #will update status.txt once done

	if read(status.txt) == "DONE"
		run_COMSOL_CFD()
		save_COMSOL_results(result.csv)
		result = read_csv(result.csv)

		tag = "I"
		fitness_gen.append([result;tag])


sort(fitness_gen, decreasing) #(BUT ALSO NEED TO STORE THEIR INDICES)
fitness_gen_index = [...] #to match the fitness scores to individual members of the generation
fitness_history.append(fitness_gen[:, 1])


## ACTUAL GA

convergence_conditions = ... #for now should be just no. of generations
generation = 0

P = ... #even no. of parents chosen from prevs generation
c_rate = 1 / ... #crossover rate (inverse should be an inteeger)
m_rate = 1 / ... #mutation rate (inverse should be an inteeger)

if mod(P, 2) != 0
	print("ERROR: P is not even!")

C = ... #no. of children for each subgroup


# Repeat until convergence reached
while not convergence_conditions
	generation = generation + 1

	# Choose P best parents
	curv1_parents = []
	curv2_parents = []
	curv3_parents = []

	for i = 1 to P
		curv1_parents.append(:, 3 * curv1[fitness_gen_index[i]])
		curv2_parents.append(:, 3 * curv2[fitness_gen_index[i]])
		curv3_parents.append(:, 3 * curv3[fitness_gen_index[i]])

	# Reset the generation dataset to include the parent subgroup
	curv1 = [curv1_parents]
	curv2 = [curv2_parents]
	curv3 = [curv3_parents]

	# To prevent overriding the parents
	curv1_parents_temp = curv1_parents
	curv2_parents_temp = curv2_parents
	curv3_parents_temp = curv3_parents

	# Create crossover subgroup
	for i = 2 to 4
		for j = 1:6:3*P
			crand1 = random(1 / c_rate, integer)
			crand2 = random(1 / c_rate, integer)
			crand3 = random(1 / c_rate, integer)

			if crand1 == 1
				temp = curv1_parents_temp[i, j:j+2]
				curv1_parents_temp[i, j:j+2] = curv1_parents_temp[i, j+3:j+5]
				curv1_parents_temp[i, j+3:j+5] = temp

			elif crand2 == 1
				temp = curv2_parents_temp[i, j:j+2]
				curv2_parents_temp[i, j:j+2] = curv2_parents_temp[i, j+3:j+5]
				curv2_parents_temp[i, j+3:j+5] = temp
			elif crand3 == 1
				temp = curv3_parents_temp[i, j:j+2]
				curv3_parents_temp[i, j:j+2] = curv3_parents_temp[i, j+3:j+5]
				curv3_parents_temp[i, j+3:j+5] = temp

	curv1_new = curv1_parents_temp
	curv2_new = curv2_parents_temp
	curv3_new = curv3_parents_temp

	curv1 = concat(curv1, curv1_new)
	curv2 = concat(curv2, curv2_new)
	curv3 = concat(curv3, curv3_new)


	# Create crossover + mutation subgroup
	for i = 2 to 4
		for j = 1:6:3*P
			crand1 = random(1 / c_rate, integer)
			crand2 = random(1 / c_rate, integer)
			crand3 = random(1 / c_rate, integer)
			
			if crand1 == 1
				temp = curv1_parents_temp[i, j:j+2]
				curv1_parents_temp[i, j:j+2] = curv1_parents_temp[i, j+3:j+5]
				curv1_parents_temp[i, j+3:j+5] = temp

			elif crand2 == 1
				temp = curv2_parents_temp[i, j:j+2]
				curv2_parents_temp[i, j:j+2] = curv2_parents_temp[i, j+3:j+5]
				curv2_parents_temp[i, j+3:j+5] = temp
			elif crand3 == 1
				temp = curv3_parents_temp[i, j:j+2]
				curv3_parents_temp[i, j:j+2] = curv3_parents_temp[i, j+3:j+5]
				curv3_parents_temp[i, j+3:j+5] = temp

		for j = 2 : 3 : 3*P
			mrand1 = random(1 / m_rate, integer)
			mrand2 = random(1 / m_rate, integer)

			if mrand1 == 1
				curv1_parents_temp[j, 2] = random(curv1_YBOUND, decimal)

			if mrand2 == 1
				curv2_parents_temp[j, 2] = random(curv2_YBOUND, decimal)
				curv2_parents_temp[j, 3] = a * curv2_new[j, 2] + b

		for j = 3 : 3 : 3*P
			mrand3 = random(1 / m_rate, integer)

			if mrand3 == 1
				curv3_parents_temp[j, 3] = random(curv1_YBOUND, decimal)

	curv1_new = curv1_parents_temp
	curv2_new = curv2_parents_temp
	curv3_new = curv3_parents_temp

	curv1 = concat(curv1, curv1_new)
	curv2 = concat(curv2, curv2_new)
	curv3 = concat(curv3, curv3_new)



	# Create mutation only subgroup
	for i = 2 to 4
		for j = 2 : 3 : 3*P
			mrand1 = random(1 / m_rate, integer)
			mrand2 = random(1 / m_rate, integer)

			if mrand1 == 1
				curv1_parents_temp[j, 2] = random(curv1_YBOUND, decimal)

			if mrand2 == 1
				curv2_parents_temp[j, 2] = random(curv2_YBOUND, decimal)
				curv2_parents_temp[j, 3] = a * curv2_new[j, 2] + b

		for j = 3 : 3 : 3*P
			mrand3 = random(1 / m_rate, integer)

			if mrand3 == 1
				curv3_parents_temp[j, 3] = random(curv1_YBOUND, decimal)


	curv1_new = curv1_parents_temp
	curv2_new = curv2_parents_temp
	curv3_new = curv3_parents_temp

	curv1 = concat(curv1, curv1_new)
	curv2 = concat(curv2, curv2_new)
	curv3 = concat(curv3, curv3_new)



	# Fitness testing, continued
	fitness_gen = [] #will store the results from this generation

	for i = 1 : 3 : 3*(P + 3*C)
		curv1_temp = curv1[:, i:i+2]
		curv2_temp = curv2[:, i:i+2]
		curv3_temp = curv3[:, i:i+2]
		save_to_CSV(coords.csv, curv1_temp)
		save_to_CSV(coords.csv, curv2_temp)
		save_to_CSV(coords.csv, curv3_temp)

		write_to_TXT(status.txt, "WORKING")
		run_solidworks_macro() #that script will update status.txt once done

		if read(status.txt) == "DONE"
			run_COMSOL_CFD()
			save_COMSOL_results(result.csv)
			result = read_csv(result.csv)

			if i <= P
				tag = "P"
			elif P < i < P + C
				tag = "C"
			elif P + C < i <= P + 2*C
				tag = "CM"
			elif P + 2*C < i <= P + 3*C
				tag = "M"


			fitness_gen.append([result; tag])


	[temp, order] = sort(fitness_gen) #(BUT ALSO NEED TO STORE THEIR INDICES)
	fitness_gen = fitness_gen[:, order]
	fitness_history.append(fitness_gen[:, 1])





# At the end, print the best results / store them as a variable and also update the CAD model with them (by running the macro)
# and also plot the convergence over generations


# Current issues: need to make sure amount of mutated children is ok (currently generates 3 * P + 1, should be either P + 3 * C
# (with C being appropriate given P) or 3 * P + C, although then have to choose which one to mutate)







