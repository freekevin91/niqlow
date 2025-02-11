#include "KeaneWolpinREStat1994.h"
/* This file is part of niqlow. Copyright (C) 2012-2018 Christopher Ferrall */

DynamicRoy::Replicate()	{
	decl i, BF, KW,OutMat, AMat, BMat, BFsim, KWsim;	
	Initialize(new DynamicRoy());
	SetClock(NormalAging,A1);
	Actions(accept = new ActionVariable("Accept",Msectors));

//    GroupVariables(lnk = new NormalRandomEffect("lnk",3,0.0,1.0));
    lnk = 1.0;
	EndogenousStates(attended   = new ActionTracker("attended",accept,school));
	ExogenousStates(offers = new MVNormal("eps",Msectors,Noffers,zeros(Msectors,1),sig));
//    offers->SetVolume(LOUD);
	xper = new array[Msectors-1];
	for (i=0;i<Msectors-1;++i)
		EndogenousStates(xper[i] = new ActionCounter("X"+sprint(i),MaxExp,accept,i,0));
	SetDelta(0.95);
    R = [=]() {
 	   decl  xs = xper[school].v, xw = xper[white].v, xb = xper[blue].v,
            k = AV(lnk), //could be unobserved heterogeneity, but now just intercept
	        xbw = (k~xs~xw~-sqr(xw)~xb~-sqr(xb))*alph[white],
	        xbb = (k~xs~xb~-sqr(xb)~xw~-sqr(xw))*alph[blue];
        return
	        xbw	
	       |xbb
	       | bet[0]-bet[1]*(xs+School0>=HSGrad)-bet[2]*!CV(attended)
	       | gamm;
            };
	CreateSpaces(NoSmoothing); //LogitKernel,1/4000.0
	BF = new ValueIteration();
	BF -> Solve();
	println("Brute force time: ",timer()-cputime0);
    BFsim = new Panel(0);
    BFsim -> Simulate(1000,30);
    BFsim -> Print("KW94_brute.dta",LONG);
	DPDebug::outV(FALSE,&AMat);
    /*savemat("KWbrute.dta",AMat,DPDebug::SVlabels); */
    SubSampleStates(constant(1.0,1,3)~constant(0.1,1,A1-3),30);
	KW = new KeaneWolpin();
	KW -> Solve();
	println("KW solve time: ",timer()-cputime0);
    KWsim = new Panel(1);
    KWsim -> Simulate(1000,30);
    KWsim -> Print("KW94_approx.dta",LONG);
	DPDebug::outV(FALSE,&BMat);
/*    savemat("KWapprox.dta",BMat,DPDebug::SVlabels); */
    decl nc = columns(BMat)-Msectors-1;
    println("EV and Choice Prob. ",
        "Brute Force ",MyMoments(AMat[][nc:]),
        "Approx ",MyMoments( BMat[][nc:]),
        "Abs. Diff ",MyMoments(fabs((BMat-AMat)[][nc:])))
        ;
//    println("differences ","%c",{"EV","Choice Probs"},);
    delete BF, KW,BFsim, KWsim;
    Delete();
}

/** Rule out schooling if too old **/
DynamicRoy::FeasibleActions() {
	return (I::t+Age0>MaxAgeAtt) ? Alpha::C.!=school : ones(Alpha::N,1);
	}
	
/** Total experience cannot exceed age;  Total schooling limited.**/	
DynamicRoy::Reachable() {
	decl i,totexp;
	for (i=0,totexp=0;i<Msectors-1;++i) totexp += xper[i].v;
	return !(I::t<min(A1,totexp) || xper[school].v>MaxXtraSchool);
 	}

/** Utility vector equals the vector of feasible returns.**/	
DynamicRoy::Utility() {
    decl rr = R(), ee = AV(offers);
	rr[:blue] = exp(rr[:blue]+ee[:blue]);
	rr[school:] += ee[school:];
	return rr[Alpha::C];
	}
