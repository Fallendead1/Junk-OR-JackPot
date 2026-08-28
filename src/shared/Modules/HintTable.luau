-- Grade -> hint distributions. Source: GDD §4.7.
-- Each lump draws 3 independent hints (Weight, Temperature, Sheen); each draw
-- picks Low/Mid/High using its grade's row below.
return {
	Dud = { Low = 0.70, Mid = 0.25, High = 0.05 },
	Plain = { Low = 0.35, Mid = 0.45, High = 0.20 },
	Promising = { Low = 0.12, Mid = 0.38, High = 0.50 },
	Charged = { Low = 0.04, Mid = 0.21, High = 0.75 },

	-- The words shown to the player for each hint type's Low/Mid/High level.
	Labels = {
		Weight = { Low = "Light", Mid = "Solid", High = "Heavy" },
		Temperature = { Low = "Cold", Mid = "Warm", High = "Hot" },
		Sheen = { Low = "Dull", Mid = "Faint", High = "Shimmering" },
	},
}
