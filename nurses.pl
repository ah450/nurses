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
NextNurse is Nurse - 1, 
nurse_schedule(ShiftSchedule, Nurse, NurseSchedule),
%% print(NurseSchedule),
sum(NurseSchedule, #=<, Max),
max_shifts_per_nurse(ShiftSchedule, NextNurse, Max).


combine_schedules([MH|[]], [EH|[]], [NH|[]], [MH, EH, NH]).
combine_schedules(MorningSchedule, EveningSchedule, NightSchedule, CombinedSchedule):-
MorningSchedule = [MH | MT], EveningSchedule = [EH|ET], NightSchedule = [NH|NT],
combine_schedules(MT, ET, NT, RestCombined),
CombinedSchedule = [MH, EH, NH | RestCombined].

nurse_break(MorningSchedule, EveningSchedule, NightSchedule):-
combine_schedules(MorningSchedule, EveningSchedule, NightSchedule, CombinedSchedule),
automaton(CombinedSchedule, [source(a), sink(a), sink(b), sink(c)], 
    [arc(a, 0, a), arc(a, 1, b), arc(b, 0, c), arc(c, 0, a)]).


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
NumNurses #=< 8 * P, NumNurses #> 0,
% Minimize number of nurses.
% Add the second dimension to our matrices
add_dimension(MorningShifts, NumNurses),
add_dimension(EveningShifts, NumNurses),
add_dimension(NightShifts, NumNurses),
NursesZeroBased #= NumNurses - 1,
% No nurse can work more than 4 night shifts per P
max_shifts_per_nurse(NightShifts, NursesZeroBased, 4),
% 11 hour breaks
maplist(nurse_break, MorningShifts, EveningShifts, NightShifts),
% Constraints on minimum number of nurses on each shift type
min_per_shift(MorningShifts, 3),
min_per_shift(EveningShifts, 3),
min_per_shift(NightShifts, 2),
% Label our schedule
VarsNested = [MorningShifts, EveningShifts, NightShifts, NumNurses],
flatten(VarsNested, Vars),
labeling([ffc, min(NumNurses)], Vars).



