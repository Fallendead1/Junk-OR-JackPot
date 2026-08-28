-- Precomputed 5x3 blind-offer lookup. Source: GDD §5.3.
--
-- blindPrice(zone, hintScore) = round(Config.BLIND_RATIO * BucketEV[zone][bucket])
-- BUCKET = { [0]="LOW", [1]="LOW", [2]="MID", [3]="MID", [4]="MID", [5]="HIGH", [6]="HIGH" }
--
-- The GDD publishes the final offers (e.g. Zone 1: 40 / 140 / 525), not these
-- raw EVs directly — it calls BucketEV "generated offline". These values are
-- back-derived as offer / BLIND_RATIO so the formula above reproduces every
-- published offer in §5.3 exactly at BLIND_RATIO = 0.70. Verified for all 5
-- zones before committing.
return {
	[1] = { LOW = 57.14, MID = 200.00, HIGH = 750.00 },
	[2] = { LOW = 178.57, MID = 621.43, HIGH = 2328.57 },
	[3] = { LOW = 571.43, MID = 1985.71, HIGH = 7428.57 },
	[4] = { LOW = 1500.00, MID = 5228.57, HIGH = 19571.43 },
	[5] = { LOW = 2457.14, MID = 9285.71, HIGH = 25857.14 },
}
