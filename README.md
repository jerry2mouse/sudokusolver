# sudokusolver
sudoku solver 
推导加猜测。
logical deductions, and guess.

world hardest sudoku puzzle, guess it.

-- from openai
To remove candidate numbers from cells using the rules of Sudoku, you typically use logical deduction techniques. Here are some common rules and strategies to remove candidate numbers from cells:

Naked Pairs, Naked Triples, and Naked Quads:

Look for rows, columns, or boxes where a specific set of two, three, or four numbers appears as candidates in the same cells. When you identify such sets, you can eliminate those numbers as candidates from other cells in the same unit.
Hidden Singles:

If a particular number can only be placed in one cell in a unit (row, column, or box) due to the constraints of that unit, that cell must contain that number. You can confidently fill in the number and remove it as a candidate from other cells in the same unit.
Locked Candidates:

If a number is a candidate in all cells of a specific row or column within a box, you can eliminate that number as a candidate from other cells in the same row or column outside the box.
