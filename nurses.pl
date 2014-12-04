:- use_module(library(clpfd)).



add_dimension([], _).
add_dimension([H|T], D):-
length(H, D), H ins 0..1, add_dimension(T, D).


min_per_shift([], _).
min_per_shift([H|T], M):-
sum(H, #>=, M), min_per_shift(T, M).

nurse_schedule([], _, []).
% Get a specific nurses schedule for a certain shift over
% all days
nurse_schedule(ShiftSchedule, NurseID, NurseSchedule):-
ShiftSchedule = [DaySchedule|T], nth0(NurseID, DaySchedule, NurseD),
nurse_schedule(T, NurseID, NurseScheduleRest),
NurseSchedule = [NurseD | NurseScheduleRest].


max_shifts_per_nurse(_, -1, _).
% Nurse should start with NumNurses -1 (zero based)
max_shifts_per_nurse(ShiftSchedule, Nurse, Max):-
NextNurse #= Nurse - 1, 
nurse_schedule(ShiftSchedule, Nurse, NurseSchedule),
sum(NurseSchedule, #=<, Max),
max_shifts_per_nurse(ShiftSchedule, NextNurse, Max).


combine_schedules([MH|[]], [EH|[]], [NH|[]], [MH, EH, NH]).
combine_schedules(MorningSchedule, EveningSchedule, NightSchedule, CombinedSchedule):-
MorningSchedule = [MH | MT], EveningSchedule = [EH|ET], NightSchedule = [NH|NT],
combine_schedules(MT, ET, NT, RestCombined),
CombinedSchedule = [MH, EH, NH | RestCombined].

nurse_day_schedule_helper(MorningShifts, EveningShifts, NightShifts, NurseID, DaySchedule):-
nurse_schedule(MorningShifts, NurseID, MorningSchedule),
nurse_schedule(EveningShifts, NurseID, EveningSchedule),
nurse_schedule(NightShifts, NurseID, NightSchedule),
combine_schedules(MorningSchedule, EveningSchedule, NightSchedule, DaySchedule).

%% Num nurses is zero based
nurse_day_schedule(MorningSchedule, EveningSchedule, NightSchedule, NumNurses, Schedules):-
numlist(0, NumNurses, IDS),
maplist(nurse_day_schedule_helper(MorningSchedule, EveningSchedule, NightSchedule), IDS, Schedules).

working_days([], []).
working_days([M, E, N | T], Days):-
sum([M, E, N], #= , K), K in 0..1, working_days(T, DaysRest), Days = [K | DaysRest].

% Days schedule is P * 3 length
nurse_shift_break(NurseDaySchedule):-
automaton(NurseDaySchedule, [source(a), sink(a), sink(b), sink(c)], 
    [arc(a, 0, a), arc(a, 1, b), arc(b, 0, c), arc(c, 0, a)]).

working_days_limit(NurseWorkingDays):-
% DFA that requires atleast 1 zero in a sequence of 6 symbols
Nodes = [source(a), sink(a), sink(b), sink(c), sink(d), sink(e), sink(f)],
Arcs = [arc(a, 0, a), arc(a, 1, b), arc(b, 1, c), arc(c, 1, d), 
arc(d, 1, e), arc(e, 1, f), arc(f, 0, a), arc(e, 0, a), arc(d, 0, a), 
arc(c, 0, a), arc(b, 0, a)], 
automaton(NurseWorkingDays, Nodes, Arcs),
% DFA that accepts atmost 2 zeros in a sequence of 5 symbols 
Nodes2 = [source(a), sink(a), sink(b), sink(c), sink(d), sink(e), sink(f),
sink(g), sink(h), sink(i), sink(j), sink(k), sink(i)],
Arcs2 = [arc(a, 0, b), arc(a, 1, i), arc(b, 1, c), arc(b, 0, f), arc(c, 1, d), 
arc(c, 0, g), arc(d, 1, e), arc(d, 0, h), arc(e, 1, a), arc(e, 0, a), 
arc(f, 1, g), arc(g, 1, h), arc(h, 1, a), arc(i, 1, j), arc(i, 0, c), arc(j, 0, d),
arc(j, 1, k), arc(k, 0, e), arc(k, 1, c), arc(c, 1, a), arc(c, 0, 1)],
automaton(NurseWorkingDays, Nodes2, Arcs2),
% No bride Days
Nodes3 = [source(a), sink(a), sink(b), sink(c)],
Arcs3 = [arc(a, 1, a), arc(a, 0, b), arc(b, 0, a), arc(b, 1, c), arc(c, 1, a)],
automaton(NurseWorkingDays, Nodes3, Arcs3).

% Model Notes:
% We are using a boolean representation 
% In 3 matrices, Each PxNumNurses, where P is the scheduling period
% Each matrix represents a shift type.
% Structure is row major as nested lists.
% For example MorningShifts[1][0] = 1 iff Nurse with ID 0 is on the morning
% shift of day one.
schedule(MorningShifts, EveningShifts, NightShifts, NumNurses, P):-
% Construct first dimension of the three matrices.
length(MorningShifts, P), length(EveningShifts, P),
length(NightShifts, P), 
NumNurses #=< 8 * P, NumNurses #>= 8,
% Minimize number of nurses.
% Add the second dimension to our matrices
add_dimension(MorningShifts, NumNurses),
add_dimension(EveningShifts, NumNurses),
add_dimension(NightShifts, NumNurses),
min_per_shift(MorningShifts, 3),
min_per_shift(EveningShifts, 3),
min_per_shift(NightShifts, 2),
NursesZeroBased #= NumNurses - 1,
% No nurse can work more than 4 night shifts per P
max_shifts_per_nurse(NightShifts, NursesZeroBased, 4),
% NurseDaySchedules is list of each nurse's schedule.
nurse_day_schedule(MorningShifts, EveningShifts, NightShifts, NursesZeroBased, NurseDaySchedules),
maplist(working_days, NurseDaySchedules, NurseWorking),
% Minimum of one day off per 6 days, max two per 5, no bridge days
maplist(working_days_limit, NurseWorking),
% Constraints on minimum number of nurses on each shift type
% Label our schedule
%% VarsNested = [NurseWorking,NumNurses, MorningShifts, EveningShifts, NightShifts],
VarsNested = [NumNurses, NurseDaySchedules],
flatten(VarsNested, Vars),
labeling([ffc, min(NumNurses)], Vars).



