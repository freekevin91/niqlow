#ifndef Mh
    #include "ReservationValues.h"
#endif
/* This file is part of niqlow. Copyright (C) 2011-2018 Christopher Ferrall */


/** Create a system of nonlinear equations to solve for reservation values.
@param LB `AV` compatible lower bound on the value of the first reservation value
@param Ncuts number of reservation values
**/
Rsystem::Rsystem(LB,Ncuts,METHOD) {
	lbv = CV(LB);
	System("R",Ncuts);
	if (Ncuts>1)
		Block(zstar = new Increasing("R*",LB,Ncuts));
	else
		Parameters(zstar = (lbv==-.Inf) ? new Free("R*",1.0) : new BoundedBelow("R*",LB,lbv+1.1) );
	switch(METHOD) {
		case UseDefault:
		case USEBROYDEN:
			meth = new Broyden(this);
			break;									
		case USENEWTONRAPHSON:
			meth = new NewtonRaphson(this);
            break;
        default : break;
		}
    Volume = meth.Volume= SILENT;
    meth.USELM = (Ncuts==1);
	}
	
/** Objective for reservation value system (static EV).
@internal
**/
Rsystem::vfunc() {	
    return dV + diagonal(DeltaV(curth->Uz(CV(zstar)')))';
    }

/** Objective for DYNAMIC reservation value system.
@internal
**/
DynamicRsystem::vfunc() { return DeltaV( curth->DynamicActVal(CV(zstar)') ); }
DynamicRsystem::DynamicRsystem(LB,Ncuts,METHOD) {
        Rsystem(LB,Ncuts,METHOD);
    }

Rsystem::RVSolve(dV) {
	this.curth = I::curth;
	this.dV = dV;
	Encode(setbounds(curth->Getz()[],lbv+1.1,.Inf));
	meth->Iterate();
	curth->Setz(CV(zstar));
    return curth->thetaEMax();
	}

/** Solve for reservation values.
@param LB `AV` compatible lower bound on the value of the first reservation value.<br>Optional: Default =-.Inf.
@param METHOD Integer `SystemAlgorithms` code for non-linear system algorithm to use.<br>Optional: UseDefault (Broyden).

**/
ReservationValues::ReservationValues(LBvalue,METHOD) {
	Method(new RVGSolve(LBvalue,METHOD,this));
    Volume = SILENT;
	}

ReservationValues::Solve(Fgroups,Rgroups) {
    Method::Initialize();
    Method::Solve(Fgroups,Rgroups);
    }

RVGSolve::Solve(state) {
    decl rv;
    foreach (rv in RValSys) if (isclass(rv)) { rv.meth.Volume = max(SILENT,Volume-1); rv.meth->Tune(MaxTrips); }
    GSolve::Solve(state);

	this.state = state;
    //Clock::Solving(&VV);
    ZeroTprime();
    this->Traverse();
	Flags::setPstar = counter->setPstar();   // REMOVED MaxTrips??? See GSolve().
	if (!(I::all[onlyrand])  && isclass(counter,"Stationary")&& I::later!=LATER)
            N::VV[LATER][] = N::VV[I::later][];    //initial value next time
    Hooks::Do(PostGSolve);
    if (Volume>SILENT && N::G>1) print(".");
    }

RVGSolve::RVGSolve(LBvalue,Method,caller) {
    GSolve(caller);
	decl i,sysize;
    RValSys={};
    for (i=0;i<N::J;++i) {
        sysize = int(N::Options[i])-1;
        RValSys |= sysize
			 ? (Flags::HasKeptZ
                    ? new DynamicRsystem(LBvalue,sysize,Method)
                    : new Rsystem(LBvalue,sysize,Method))
			 :  0;
        }
    Volume = SILENT;
    }

RVGSolve::Run() {
    decl ns = I::curth.solvez && isclass(RValSys[I::curth.Aind]);
    XUT.state = state;
    //DP::vV =VV[I::later];
    I::curth->ActVal();
    //ev =
    N::VV[I::now][I::all[iterating]]
                            = ns
                                ? RValSys[I::curth.Aind] -> RVSolve(DeltaV(I::curth.pandv))
                                : I::curth->thetaEMax();
    this->PostEMax();
//    return V;
    }

/**  Simplified Reservation Value Iteration model solution.

@param ToScreen  TRUE [default] means output is displayed .
@param aM	address to return matrix<br>0, do not save [default]
<DT>Note:  All parameters are optional, so <code>VISolve()</code> works.</DT>
<DT>This function</DT>
<DD>Creates a `ReservationValues` method</dd>
<dd>Calls `DPDeubg::outAllV`(<parameters>)</dd>
<DD>Calls `ReservationValues::Solve`()</dd>
<dd>deletes the solution method</dd>

This routine simplifies basic reservation value solving.  Simply call it after calling `DP::CreateSpaces`().
Its useful for debugging and demonstration purposes because the user's code does not need to create
the solution method object and call solve.

This would be inefficient to use in any context when a solution method is applied repeatedly.

**/
RVSolve(ToScreen,aM) {
	if (!Flags::ThetaCreated) oxrunerror("DDP Error 27. Must call CreateSpaces() before calling RVSolve()");
    decl meth = new ReservationValues();
	DPDebug::outAllV(ToScreen,aM);
    //meth.Volume = NOISY;
	decl conv = meth->Solve();
    delete meth;
    return conv;
    }
