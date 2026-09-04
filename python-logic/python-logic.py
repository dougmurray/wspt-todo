"""
User inputs the task, time, and importance level. 
The time is in minutes, while the importance is based on the word list:
Trivial, Low, Normal, High, or Critical
with them corresponding to the numbers 1, 2, 3, 4, 5 respectively.
These values are stored as the importance value for the task.
"""

# Example todo items, default weighted_values is 0 (NaN)
item_one = {
    "task": "take out trash",
    "time": 20,
    "importance": 3,
    "weighted_value": 0
}

item_two = {
    "task": "take recycling out",
    "time": 30,
    "importance": 5,
    "weighted_value": 0
}

# Gather the todo items in a single searchable list
items = [item_one, item_two]

# How to calculate and add the actual weighted_values of the todo items
for i, element in enumerate(items):
    weighted_value = element["importance"] / element["time"]
    element["weighted_value"] = weighted_value

# Now todo list items have actual weighted_values values
print(items)

# Sorts the original todo items list in place, reverse=True for descending order 5, 4, 3, etc.
items.sort(key=lambda x: x["weighted_value"], reverse=True)
print(items)
