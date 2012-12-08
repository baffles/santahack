###
	Hungarian module
	Loosely based on Munkres (http://pypi.python.org/pypi/munkres/)
	by BAF
###

module.exports = class Hungarian
	constructor: () ->
	
	padMatrix: (matrix, padValue = 0) ->
		###
			Pad a possibly non-square matrix to make it square.
			
        	Parameters:
            	matrix: matrix to pad
	            pad_value: value to use to pad the matrix
			
	        Returns a new matrix, padded if necessary
		###
		
		columns = 0
		rows = matrix.length
		
		for row in matrix
			columns = Math.max(columns, row.length)
		
		size = Math.max(columns, rows)
		
		newMatrix = []
		for row in matrix
			newMatrix.push if row.length < size then row.concat (0 for i in [1..size-row.length]) else row.concat []
		
		while newMatrix.length < size
			newMatrix.push (0 for i in [1..size])
		
		newMatrix
	
	compute: (costMatrix) ->
		###
        	Compute the indexes for the lowest-cost pairings between rows and
	        columns in the database. Returns a list of (row, column) tuples
	        that can be used to traverse the matrix.

	        Parameters
	            cost_matrix:
	                The cost matrix. If this cost matrix is not square, it
	                will be padded with zeros, via a call to pad_matrix().
	                (This method does *not* modify the caller's matrix. It
	                operates on a copy of the matrix.)

	                **WARNING**: This code handles square and rectangular
	                matrices. It does *not* handle irregular matrices.

	        Returns a mapping of row->col that describe the lowest cost path through the matrix
		###
		
		@matrix = @padMatrix costMatrix
		@size = @matrix.length
		originalLength = costMatrix.length
		originalWidth = costMatrix[0].length
		@rowCovered = (false for i in [1..@size])
		@colCovered = (false for i in [1..@size])
		@z0r = 0
		@z0c = 0
		@path = @__make_matrix @size * 2, 0
		@marked = @__make_matrix @size, 0
		
		done = false
		step = 1
		
		steps = [ null, (=> @__step1()), (=> @__step2()), (=> @__step3()), (=> @__step4()), (=> @__step5()), (=> @__step6()) ]
		
		while not done and step != true and steps[step]?
			step = steps[step]()
		
		# Look for the starred columns
		results = []
		for y in [0..originalLength-1]
			for x in [0..originalWidth-1]
				if @marked[y][x] is 1
					results.push { y, x }
		
		results
	
	__make_matrix: (n, value) ->
		# Creates an n*n matrix populated with the given value
		matrix = []
		matrix.push(value for x in [1..n]) for y in [1..n]
		matrix
	
	__step1: () ->
		# For each row of the matrix, find the smallest element and
		# subtract it from every element in its row. Go to Step 2.
		for row in @matrix
			minVal = Hungarian.minInRow row
			row[i] -= minVal for i in [0..row.length-1]
		
		2
	
	__step2: () ->
		# Find a zero (Z) in the resulting matrix. If there is no starred
		# zero in its row or column, star Z. Reeat for each element in the
		# matrix. Go to Step 3.
		
		for y in [0..@size-1]
			for x in [0..@size-1]
				if @matrix[y][x] is 0 and not @colCovered[x] and not @rowCovered[y]
					@marked[y][x] = 1
					@colCovered[x] = true
					@rowCovered[y] = true
		
		@__clear_covers()
		3
	
	__step3: () ->
		# Cover each column containing a starred zero. If K columns are
		# covered, the starred zeros describe a complete set of unique
		# assignments. In this case, done, otherwise, go to step 4.
		
		count = 0
		for y in [0..@size-1]
			for x in [0..@size-1]
				if @marked[y][x] is 1
					@colCovered[x] = true
					count++
		
		step = 4
		if count >= @size
			step = true # done
		
		step
	
	__step4: () ->
		# Find a noncovered zero and prime it. If there is no starred zero
		# in the row containing this primed zero, go to step 5. Otherwise,
		# cover this row and uncover the column containing the starred
		# zero. Continue in this manner until there are no uncovered zeros
		# left. Save the smallest uncovered value and go to step 6.
		
		step = 0
		done = false
		
		while not done
			[row, col] = @__find_a_zero()
			if row < 0
				done = true
				step = 6
			else
				@marked[row][col] = 2
				starCol = @__find_star_in_row row
				if starCol >= 0
					col = starCol
					@rowCovered[row] = true
					@colCovered[col] = false
				else
					done = true
					@z0r = row
					@z0c = col
					step = 5
		
		step
	
	__step5: () ->
		# Construct a series of alternating primed and starred zeros as
		# follows. Let Z0 represent the uncovered primed zero found in step 4.
		# Let Z1 denote the starred zero in the column of Z0 (if any).
		# Let Z2 denote the primed zero in the row of Z1 (there will always
		# be one). Continue until the series terminates at a primed zero
		# that has no starred zero in its column. Unstar each starred zero
		# of the series, star each primed zero of the series, erase all
		# primes and uncover every line in the matrix. Return to step 3.
		
		count = 0
		@path[count][0] = @z0r
		@path[count][1] = @z0c
		done = false
		
		while not done
			row = @__find_star_in_col @path[count][1]
			if row >= 0
				count++
				@path[count][0] = row
				@path[count][1] = @path[count-1][1]
			else
				done = true
			
			if not done
				col = @__find_prime_in_row @path[count][0]
				count++
				@path[count][0] = @path[count-1][0]
				@path[count][1] = col
		
		@__convert_path @path, count
		@__clear_covers()
		@__erase_primes()
		
		3
	
	__step6: () ->
		# Add the value found in step 4 to every element of each covered
		# row, and subtract it from every element of each uncovered column.
		# Return to step 4 without altering any stars, primes, or covered
		# lines.
		
		minVal = @__find_smallest()
		
		for y in [0..@size-1]
			for x in [0..@size-1]
				if @rowCovered[y]
					@matrix[y][x] += minVal
				if not @colCovered[x]
					@matrix[y][x] -= minVal
		
		4
	
	__find_smallest: () ->
		# Find the smallest uncovered value in the matrix.
		minVal = Number.MAX_VALUE
		
		for y in [0..@size-1]
			for x in [0..@size-1]
				if not @rowCovered[y] and not @colCovered[x]
					minVal = Math.min minVal, @matrix[y][x]
		
		minVal
	
	__find_a_zero: () ->
		# Find the first uncovered element with value 0
		
		row = -1
		col = -1
		done = false
		
		y = 0
		while not done and y < @size
			x = 0
			while x < @size
				if @matrix[y][x] is 0 and not @rowCovered[y] and not @colCovered[x]
					row = y
					col = x
					done = true
				x++
			y++
		
		return [row, col]
	
	__find_star_in_row: (row) ->
		# Find the first starred element in the specified row. Returns
		# the column index, or -1 if no starred element was found.
		
		for x in [0..@size-1]
			if @marked[row][x] is 1
				return x
		
		-1
		
	__find_star_in_col: (col) ->
		# Find the first starred element in the specified row. Returns
		# the row index, or -1 if no starred element was found.
		
		for y in [0..@size-1]
			if @marked[y][col] is 1
				return y
		
		-1
	
	__find_prime_in_row: (row) ->
		# Find the first prime element in the specified row. Returns
		# the column index, or -1 if no starred element was found.
		
		for x in [0..@size-1]
			if @marked[row][x] is 2
				return x
				break
		
		-1
	
	__convert_path: (path, count) ->
		for y in [0..count]
			if @marked[path[y][0]][path[y][1]] is 1
				@marked[path[y][0]][path[y][1]] = 0
			else
				@marked[path[y][0]][path[y][1]] = 1

	__clear_covers: () ->
		# Clear all covered matrix cells
		
		for i in [0..@size-1]
			@rowCovered[i] = false
			@colCovered[i] = false
	
	__erase_primes: () ->
		# Erase all prime markings
		for y in [0..@size-1]
			for x in [0..@size-1]
				@marked[y][x] = 0 if @marked[y][x] is 2
	
	# Utilities
	@makeCostMatrix: (profitMatrix, iterator) ->
		costMatrix = []
		for row in profitMatrix
			costMatrix.push row.map iterator
		costMatrix
	
	@minInRow: (array) ->
		min = array[0]
		min = Math.min(min, val) for val in array
		min

### tests:
matrices = [
	# Square
	[[[400, 150, 400],
	  [400, 450, 600],
	  [300, 225, 300]],
	  850 # expected cost
	],

	# Rectangular variant
	[[[400, 150, 400, 1],
	  [400, 450, 600, 2],
	  [300, 225, 300, 3]],
	  452 # expected cost
	],

	# Square
	[[[10, 10,  8],
	  [ 9,  8,  1],
	  [ 9,  7,  4]],
	  18
	],

	# Rectangular variant
	[[[10, 10,  8, 11],
	  [ 9,  8,  1, 1],
	  [ 9,  7,  4, 10]],
	  15
	]
]

h = new Hungarian()

for [costMatrix, expTotal] in matrices
	console.log 'Cost matrix:'
	console.dir costMatrix
	assignments = h.compute costMatrix
	totalCost = 0
	for assn in assignments
		cost = costMatrix[assn.y][assn.x]
		totalCost += cost
		console.log "(#{assn.y}, #{assn.x}) -> #{cost}"
	console.log "Lowest cost = #{totalCost}"
	console.log "Expected total = #{expTotal}"
	console.log if totalCost is expTotal then 'Pass' else 'Fail'
	console.log '\n\n'
###
