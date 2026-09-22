
## GFM C0 branch

The project now also contains `GFM_Inverter_C0.slx`, a 5 MW / 10 MWh
grid-forming control branch built on the frozen B1 detailed switching plant.
The controller is graphical and readable: measurement/PQ, P-f angle, Q-V
magnitude, feasibility limits, and carrier PWM are separate subsystems.

See `docs/GFM_C0_ARCHITECTURE.md`. The control structure and switching smoke
test pass. The inherited B1 AC plant currently fails to produce meaningful
current under a forced grid phase displacement, so 5 MW power transfer is not
yet claimed.
