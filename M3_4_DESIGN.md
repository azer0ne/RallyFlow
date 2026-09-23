# M3.4 Fair Social Ranking Design

## Inputs and authority

`ParticipantMatchHistory` remains authoritative for completed-match counts, eligible-wait
streaks, consecutive completed participation, and partner/opponent relationships.
`SessionParticipant.status` is used only for current availability and to recognize an
explicitly eligible, currently playing participant in an upcoming request. Cached counters
on `SessionParticipant` are not read or reconciled by the ranker.

Ranking requires an explicit usable-court count. The adaptive policy computes simultaneous
player capacity as `min(eligible participants, players per match * usable courts)` and the
expected rest baseline as `ceil(eligible participants / capacity) - 1`. Missing or invalid
capacity is an error; no court count is inferred.

## Primary comparison

Each candidate is projected for one scheduling opportunity without mutating history:

- selected players gain one projected match and their projected eligible-rest streak resets;
- unselected eligible players gain one projected missed opportunity;
- match deficit is the distance from the highest projected match count in the eligible pool;
- waiting excess is projected consecutive eligible rests beyond the adaptive baseline.

Both deficits count scheduling opportunities, so the ranker compares them without arbitrary
weights. Candidates minimize this tuple, in order:

1. the worst match-or-wait deficit left for any eligible participant;
2. the number of participants left at that worst deficit;
3. the aggregate match deficits plus waiting excesses across the pool.

This minimax tuple lets a severe waiting excess defeat a one-opportunity match-count benefit,
while a severe match-count deficit defeats a minor waiting benefit. Neither objective is an
unconditional winner.

## Secondary comparison and explanations

Primary ties are resolved by fewer repeated partner relationships for doubles, fewer repeated
opponent relationships, fewer participants extending consecutive play, and finally a canonical
player-grouping key. Input order, `Set` iteration, team side, `Team` identity, clocks, and random
values do not affect the result.

Reasons are emitted only for facts supported by the evaluated candidate and its peers. Warnings
report actual repeated relationships or consecutive participation. No numeric ranking value is
part of `MatchSuggestion` or any public product-facing model.

Upcoming requests may explicitly include participants whose current status is `playing`; this
does not turn an active match into completed history or increment completed-match counts. Full
active-match projection remains deferred to M3.6.
