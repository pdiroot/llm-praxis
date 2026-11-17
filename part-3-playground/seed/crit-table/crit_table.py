"""Critical hit table: what happens on a natural 1 or a natural 20."""

import sys

EFFECTS = {
    1: "Fumble: you drop your weapon.",
    19: "Critical hit: roll the damage dice twice.",
    20: "Legendary hit: roll the damage dice three times.",
}


def effect(roll):
    """Return the effect of a d20 roll, or None for a normal roll."""
    if roll >= 19:
        return EFFECTS[roll + 1]
    return EFFECTS.get(roll)


if __name__ == "__main__":
    # Accept "20" or a sum such as "18+2" from the table.
    roll = eval(sys.argv[1])
    print(effect(roll) or "A normal roll.")
