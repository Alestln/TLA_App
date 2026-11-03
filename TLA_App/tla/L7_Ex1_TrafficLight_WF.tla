----------------------- MODULE L7_Ex1_TrafficLight_WF -----------------------
(***************************************************************************)
(* Лекция 7. Пример 1 (со слабой справедливостью). Светофор.               *)
(*                                                                         *)
(* Отличие от L7_Ex1_TrafficLight_NoFairness — ОДНА строка в Spec:         *)
(*                                                                         *)
(*   Spec == Init /\ [][Next]_vars /\ WF_vars(Next)                        *)
(*                                                                         *)
(* WF_vars(Next) (Weak Fairness): «если шаг Next ПОСТОЯННО возможен,       *)
(* то он КОГДА-НИБУДЬ будет сделан». Бесконечно стоять на месте, когда     *)
(* есть куда идти, больше нельзя.                                          *)
(*                                                                         *)
(* Ожидание: все свойства выполняются, 0 ошибок.                           *)
(***************************************************************************)

VARIABLE light

vars == <<light>>

Colors == {"red", "green", "yellow"}

TypeOK == light \in Colors

Init == light = "red"

ToGreen  == light = "red"    /\ light' = "green"
ToYellow == light = "green"  /\ light' = "yellow"
ToRed    == light = "yellow" /\ light' = "red"

Next == ToGreen \/ ToYellow \/ ToRed

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)     \* <- ДОБАВИЛИ справедливость

-----------------------------------------------------------------------------
SafeTransition == [][light = "red" => light' = "green"]_light

EventuallyGreen      == <>(light = "green")
InfinitelyOftenGreen == []<>(light = "green")
RedLeadsToGreen      == (light = "red") ~> (light = "green")

=============================================================================

