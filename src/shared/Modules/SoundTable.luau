-- Reveal announcement sounds (GDD §9.1 / Phase 14 "Reveal sound design").
-- These are asset ids, not gameplay numbers, but they still have to be real
-- sounds the owner actually wants -- pick one from the Creator Store or
-- upload your own, then paste its rbxassetid:// string in below. Left blank,
-- AnnounceController simply skips playing a sound for that tier.
return {
	Scrap = "", -- dig-minigame-spec.md also reuses this one as the fail thud placeholder
	Common = "",
	Good = "",
	Rare = "",
	Epic = "", -- soft chime
	Mythic = "", -- distinct from Epic -- this is the rarer, bigger moment
	Relic = "", -- the biggest moment in the game; make it count
	Dig = "", -- dig-minigame-spec.md §4.3: plays on every accepted click, pitch varied per play
}
