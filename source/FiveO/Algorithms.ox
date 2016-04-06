#include "Algorithms.h"
/* This file is part of niqlow. Copyright (C) 2011-2016 Christopher Ferrall */

/** Base class for non-linear programming algorithms.
@param O `Objective` to work on.
**/
Algorithm::Algorithm(O) {
	nfuncmax = maxiter = INT_MAX;
	N = 0;
    this.O = O;
	OC = O.cur;
    tolerance = itoler;
	Volume = SILENT;
    lognm = classname(this)+"-On-"+O.L+date()+replace(time(),":","-")+".log";
    logf = fopen(lognm,"aV");
    fprintln(logf,"Created");
    fclose(logf);
    }

/** Tune Parameters of the Algorithm.
@param maxiter integer max. number of iterations <br>0 use current/default value
@param toler double, simplex tolerance for convergence<br>0 use current/default value
@param nfuncmax integer, number of function evaluations before resetting the simplex<br>0 use current/default value
**/
Algorithm::Tune(maxiter,toler,nfuncmax) {
	if (maxiter) this.maxiter = maxiter;	
	if (isdouble(toler)) this.tolerance = toler;
	if (nfuncmax) this.nfuncmax = nfuncmax;
	}

/** Tune NelderMead Parameters .
@param mxstarts integer number of simplex restarts<br>0 use current/default value
@param toler double, simplex tolerance for convergence<br>0 use current/default value
@param nfuncmax integer, number of function evaluations before resetting the simplex<br>0 use current/default value
@param maxiter integer max. number of iterations <br>0 use current/default value
**/
NelderMead::Tune(mxstarts,toler,nfuncmax,maxiter) {
	if (mxstarts) this.mxstarts = mxstarts;	
	if (isdouble(toler)) this.tolerance = toler;
	if (nfuncmax) this.nfuncmax = nfuncmax;
	if (maxiter) this.maxiter = maxiter;	
	}

/** Tune Parameters of the Algorithm.
@param maxiter integer max. number of iterations <br>0 use current/default value
@param toler double, simplex tolerance for convergence<br>0 use current/default value
@param nfuncmax integer, number of function evaluations before resetting the simplex<br>0 use current/default value
@param LMitmax interger, max number of line maximization iterions<br><br>0 use current/default value
**/
GradientBased::Tune(maxiter,toler,nfuncmax,LMitmax) {
    Algorithm::Tune(maxiter,toler,nfuncmax);
    if (LMitmax) this.LMitmax = LMitmax;
    }

/** Random search without annealing.
**/
RandomSearch::RandomSearch(O) {
    SimulatedAnnealing(O);
    O.RunSafe = FALSE;
    heat = 10000.0;
    shrinkage = 1.0;
    cooling = 1.0;
    }
	
/** Initialize Simulated Annealing.
@param O `Objective` to work on.

**/
SimulatedAnnealing::SimulatedAnnealing(O)  {
	Algorithm(O);
	holdpt = new LinePoint();
	chol = 0;
	heat = 1.0;
    shrinkage = 0.5;
    cooling = 0.85;
	}

/** Tune annealing parameters.
@param maxiter &gt; 0, number of iterations<br>0 do not change
@param heat &gt; 0, temperature parameter <br>0 do not change
@param cooling &in; (0,1], rate to cool, <br>0 do not change
@param shrinkage &in; (0,1], rate to shrink, <br>0 do not change
**/
SimulatedAnnealing::Tune(maxiter,heat,cooling,shrinkage)	{
	if (heat>0) this.heat = heat;
	if (maxiter) this.maxiter = maxiter;
    if (cooling>0) this.cooling = cooling;
    if (shrinkage>0) this.shrinkage = shrinkage;
	}


/** accept or reject.
**/
SimulatedAnnealing::Metropolis()	{
	decl jm=-1, j, diff;
    for(j=0;j<M;++j) {
        diff = vtries[j]-OC.v;
	    if (Volume>=LOUD) {logf = fopen(lognm,"aV"); fprintln(logf,iter~vtries[j]~(vec(tries[][j])'));    fclose(logf);}
	    if ( !isnan(diff) && (diff> 0.0) || ranu(1,1) < exp(diff/heat))	{
             jm = j;
             OC.v = vtries[jm];
             OC.F = tries[][jm];
             O->Save(lognm);
             O->CheckMax();
             ++accept;
			 }
        }
    if (accept>=N) {
		heat *= cooling;  //cool off annealing
	    chol *= shrinkage; //shrink
		if (Volume>QUIET) println("Cool Down ",iter,". f=",vtries[jm]," heat=",heat," chol=",chol);
		accept = 0;
        }
	}

/** Carry out annealing.
@param chol Determines the Choleski matrix for random draws, <var>C</var><br>
0 [default] $C = I$, the identity matrix<br>matrix, $C = $ chol.<br>double, common standard deviation, $C = chol I$.
**/
SimulatedAnnealing::Iterate(chol)	{
	O->Encode();
	N = rows(OC.F);
    if (!isclass(O.p2p) || O.p2p.IamClient) {  //MPI not running or I am the Client Node
       inp = isclass(O.p2p);
       M = inp ? O.p2P.Nodes : 1;
       Vtries=zeros(O.NvfuncTerms,M);
	   this.chol = isint(chol)  ? unit(N)
                                : isdouble(chol) ? chol*unit(N)
                                                 : ismatrix(chol) ?  chol
                                                                 :  unit(N);
	   if (OC.v==.NaN) O->fobj(0);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            O->Print("Annealing Start ",logf,Volume>QUIET);
            fclose(logf);
            }
	   OC.H = OC.SE = OC.G = .NaN;
	   accept = iter =0;	
	   do  {
	      holdpt.step = OC.F; holdpt.v = OC.v;
          tries = holdpt.step + this.chol*rann(N,M);
	      O->funclist(tries,&Vtries,&vtries);
		  Metropolis();
		} while (iter++<maxiter);
	   O->Decode(0);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            O->Print(" Annealing Done ",logf,Volume>QUIET);
            fclose(logf);
            }
       if (inp) {
            O.p2p.client->Stop();
            O.p2p.client->Announce(O.cur.X);
            }
       }
    else {
        O.p2p.server->Loop(N);
        }
	}

/** .
@internal
**/
LineMax::LineMax(O)	{
	Algorithm(O);
	p1 = new LinePoint();
	p2 = new LinePoint();
	p3 = new LinePoint();
	p4 = new LinePoint();
	p5 = new LinePoint();
	p6 = new LinePoint();
	}

SysMax::SysMax(O) {
	Algorithm(O);
	p1 = new SysLinePoint();
	p2 = new SysLinePoint();
	p3 = new SysLinePoint();
	p4 = new SysLinePoint();
	p5 = new SysLinePoint();
	p6 = new SysLinePoint();
    }

/** Delete.
@internal
**/
LineMax::~LineMax()	{
//	delete p1, p2, p3, p4, p5, p6;
	}
	
/** Optimize on a line optimization.
@param Delta vector of directions to define the line
@param maxiter &gt; 0 max. number iterations<br>0 set to 1000
**/
LineMax::Iterate(Delta,maxiter)	{
	decl maxdelt = maxc(fabs(Delta));
	this.Delta = Delta;
	this.maxiter = maxiter>0 ? maxiter : 1000;
	holdF = OC.F;
	improved = FALSE;
	p1.step = 0.0; p1.v = OC.v;
	this->Try(p2,min(maxstp/maxdelt,1.0));
	if (p2.v>p1.v) {q = p2;a=p1;} else {q=p1;a=p2;}
	b = p3;
    if (Volume>SILENT) {
        logf = fopen(lognm,"aV");
        fprintln(logf,"Line: maxiter ",maxiter,"%c",{"Direction"},"%r",O.Flabels,Delta,a,q);
        fclose(logf);
        }
    Bracket();
    if (Volume>QUIET) println("Line: past bracket",a,b,q);
	Golden();
	O->Decode(holdF+q.step*Delta);
    if (Volume>SILENT) {
        logf = fopen(lognm,"aV");
        fprintln(logf,"Past golden",q);
        if (Volume> QUIET) println("Line: past golden",q);
        fclose(logf);
        }
 	OC.v = q.v;
    if (ismember(q,"V")) OC.V = q.V;
	}
	
/** .
@internal
**/
LineMax::Try(pt,step)	{
	pt.step = step;
	O->fobj(holdF + step*Delta);
	if (isnan(pt.v = OC.v)) {
	   oxwarning("FiveO Warning 01. Objective undefined at first line try.  Trying 20% of step.\n");
	   pt.step *= .2;
	   O->fobj(holdF + pt.step*Delta);
	   if (isnan(pt.v = OC.v)) {
	           println("*** ",pt,holdF+pt.step*Delta,OC.X,"\n ****");
		      oxrunerror("FiveO Error 01. Objective undefined at line max point.\n");
            }
		}
	improved = O->CheckMax() || improved;
	}

SysMax::Try(pt,step) {
    LineMax::Try(pt,step);
    pt.V = OC.V;
    }

/** Create a Constrained Line Maximization object.
@param O `Objective`
**/
CLineMax::CLineMax(O)	{
	if (isclass(O,"UnConstrained")) oxrunerror("FiveO Error 02. Objective must be Constrained\n");
	LineMax(O);
	}

/** .
@internal
**/
CLineMax::Try(pt,step)	{
	pt.step = step;
	O->Merit(holdF + step*Delta);
	if (isnan(pt.v = OC.L)) {
	   oxrunerror("FiveO Error 03.  Lagrange undefined at first try. Trying 20% step\n");
       pt.step *= 0.2;
	   O->Merit(holdF + pt.step*Delta);
	   if (isnan(pt.v = OC.L)) {
		  println("****",pt,OC.X,"\n****");
		  oxrunerror("FiveO Error 03.  Lagrange undefined at line max point\n");
		  }
        }
	improved = O->CheckMax() || improved ;
	}
	
/** Bracket a local maximum along the line.

**/
LineMax::Bracket()	{
    decl u = p4, r, s, ulim, us, notdone;
	this->Try(b,(1+gold)*q.step-gold*a.step);
	notdone = b.v>q.v;
	while (notdone)	{
		r = (q.step-a.step)*(q.v-b.v);
		s = (q.step-b.step)*(q.v-a.v);
        us = q.step -((q.step-b.step)*s-(q.step-a.step)*r)/(2.0*(s>r ? 1 : -1)*max(fabs(s-r),tiny));
        ulim = q.step+glimit*(b.step-q.step);
        if ((q.step-us)*(us-b.step) > 0.0)	{
            this->Try(u,us);
            notdone =  (b.v>u.v)&& (u.v>=q.v);
            if (!notdone)
				{if (u.v>b.v) {a = q;q = u;} else b = u; }
            else
               this->Try(u,b.step+gold*(b.step-q.step));
			}
		else if ((b.step-us)*(us-ulim) > 0.0) {
			this->Try(u,us);
            if (u.v>b.v)
		   		{q= b; b= u; Try(u,(1+gold)*b.step-gold*q.step); }
            else if ((u.step-ulim)*(ulim-b.step) >= 0.0) this->Try(u,ulim);
            }
		else this->Try(u,(1+gold)*b.step-gold*q.step);
        if (notdone)
			{a = q;	q = b;	b = u;  notdone= b.v>q.v;  }
        if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            fprintln(logf,"Bracket ",notdone,"a:",a,"q",q,"b",b);
            fclose(logf);
            }
		}
	}

/** Golden ratio search.

**/
LineMax::Golden()	{
	decl x0 = a,  x3 = b,  x1 = p5,  x2 = p6, iter=0, s, tmp, istr;
    if (fabs(b.step-q.step) > fabs(q.step-a.step))
	  		{x1=q; this->Try(x2,q.step + cgold*(b.step-q.step));}
    else
         	{x2=q; this->Try(x1,q.step - cgold*(q.step-a.step));}
	do {
         if (x2.v>x1.v )
		  	{ s=x0; tmp = x2.step; x0=x1; x1=x2; x2=s; this->Try(x2,rgold*tmp+cgold*x3.step); }
         else
            { s=x3; tmp = x1.step; x3=x2; x2=x1; x1=s; this->Try(x1,rgold*tmp+cgold*x0.step); }
		 iter += improved;  // don't start counting until f() improves
         if (Volume>SILENT) {
                logf = fopen(lognm,"aV");
                istr = sprint("Line: ",iter,". improve: ",improved,". step diff = ",x3.step," - ",x0.step);
                fprintln(logf,istr);
                if (Volume>QUIET) println(istr);
                fclose(logf);
                }
		} while (fabs(x3.step-x0.step) > tolerance*fabs(x1.step+x2.step) && (iter<maxiter) );
    if (x1.v > x2.v) q = x1; else q= x2;
    }

/** Initialize a Nelder-Mead Simplex Maximization.

**/
NelderMead::NelderMead(O)	{
    Algorithm(O);
	step = istep;
	mxstarts =INT_MAX;
	}
	
/** Iterate on the Amoeba algorithm.
@param iplex  N&times;N+1 matrix of initial steps.<br>double, initial step size (iplex is set to 0~unit(N))<br>integer &gt; 0, max starts of the algorithm<br>0 (default), use current mxstarts.
@example
See <a href="GetStarted.html">GetStarted</a>
**/
NelderMead::Iterate(iplex)	{
	O->Encode();
    N = rows(OC.F);
    if (!isclass(O.p2p) || O.p2p.IamClient) {
	   nodeV = constant(-.Inf,N+1,1);
	   OC.SE = OC.G = .NaN;
	   iter = 1;
	   if (!ismatrix(iplex))  {
		  if (isdouble(iplex))
                step = iplex;
          else if (iplex>0) mxstarts = iplex;
		  iplex = (0~unit(N));
		  }
	   else
		  step = 1.0;
	   if (Volume>SILENT) {
          logf = fopen(lognm,"aV");
		  O->Print("Simplex Starting ",logf,Volume>QUIET);
		  fprintln(logf,"\n Max # evaluations ",nfuncmax,
				"\n Max # restarts ",mxstarts,
				"\n Plex size tolerance ",tolerance);
           fclose(logf);
		  }
	   do {
           n_func = 0;
           nodeX = reshape(OC.F,N+1,N)' + step*iplex;
	       plexshrunk = Amoeba();
	       Sort();
	       OC.F = nodeX[][mxi];
	       OC.v = nodeV[mxi];
	       holdF = OC.F;
	       if (Volume>SILENT) {
              logf = fopen(lognm,"aV");
	   		  fprintln(logf,"\n","%3u",iter,". N=","%5u",n_func," Step=","%8.5f",step,". Fmax=",nodeV[mxi]," .PlexSize=",plexsize,plexsize<tolerance ? " *Converged*" : "");
	          if (Volume>QUIET) fprintln(logf," Bounds on Simplex","%r",{"min","max"},"%c",O.Flabels,limits(nodeX')[:1][]);
              fclose(logf);
              }
	       step *= 0.9;
           } while (++iter<mxstarts && !plexshrunk && n_func < nfuncmax);
	   O->Decode(0);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            O->Print("Simplex Final ",logf,Volume>QUIET);
            fclose(logf);
            }
       if (isclass(O.p2p)) {
            O.p2p.client->Stop();
            O.p2p.client->Announce(O.cur.X);
            }
       }
    else O.p2p.server->Loop(N);
	}

/**	  Reflect through simplex.
@param fac factor
**/
NelderMead::Reflect(fac) 	{
    decl fac1, ptry, ftry;
	fac1 = (1.0-fac)/N;
	ptry = fac1*psum - (fac1-fac)*nodeX[][mni];
	O->fobj(ptry);
    O->CheckMax();
	ftry = OC.v;
	++n_func;
	atry = (ftry<nodeV[mni])
					? worst
					: (ftry > nodeV[mxi])
					    ? hi
						: (ftry > nodeV[nmni])
						      ? nxtlo
							  : lo;
	 if (atry!=worst)	{
		psum += (ptry-nodeX[][mni]);
		nodeV[mni]=ftry;
		nodeX[][mni]=ptry;
		}
	}
	
/**	 .
@internal
**/
NelderMead::Sort()	{
	decl sortind = sortcindex(nodeV);
	mxi = sortind[N];
	mni = sortind[0];
	nmni = sortind[1];
	psum = sumr(nodeX);		
	plexsize = SimplexSize();
	}

/** Compute size of the current simplex.
@return &sum;<sub>j</sub> |X-&mu;|
**/
NelderMead::SimplexSize() {
	return double(sumc(maxr(fabs(nodeX-meanr(nodeX))))); // using maxr() now
//	return (nodeV[mxi]-nodeV[mni])/max(fabs(nodeV[mxi]+nodeV[mni]),1E-7);
	}

/**	  .
@internal
**/
NelderMead::Amoeba() 	{
     decl fdiff, vF = zeros(O.NvfuncTerms,N+1);
	 n_func += O->funclist(nodeX,&vF,&nodeV);
	 do	{
	 	Sort();
		if (plexsize<tolerance) return TRUE;
		Reflect(-alpha);
        if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
		    fprint(logf,"Amoeba: ",atry==hi," ",atry>nxtlo);
            }
		if (atry==hi) {
            Reflect(gamma);
            if (Volume>SILENT) fprint(logf," ... gamma ",atry);
            }
		else if (atry>nxtlo){
			Reflect(beta);
            if (Volume>SILENT) fprint(logf," ... beta ",atry==worst);
			if (atry==worst){
				nodeX = 0.5*(nodeX+nodeX[][mxi]);
				n_func += O->funclist(nodeX,&vF,&nodeV);
				}
			}
        if (Volume>SILENT) {fprintln(logf," ... ",n_func); fclose(logf);}
		} while (n_func < nfuncmax);
	 return FALSE;
	}

/** Initialize a Gradient-Based algorithm.

**/
GradientBased::GradientBased(O) {
    Algorithm(O);
	LM = isclass(O,"UnConstrained")
			? new LineMax(O)
			: isclass(O,"Constrained")
                ? new CLineMax(O)
                : new SysMax(O);
	gradtoler = igradtoler;
    LMitmax = 10;
	}

/** Create an object of the BFGS algorithm.
@param O the `Objective` object to apply this algorithm to.

@example
<pre>
decl myobj = new MyObjective();
decl bfgs = new BFGS(myobj);
bfgs->Iterate();
</pre></dd>

<DT>See <a href="./GetStarted.html">GetStarted</a></DT>

**/
BFGS::BFGS(O) {	GradientBased(O);	}

/** Create an object of the BHHH algorithm.
@param O the `Objective` object to apply this algorithm to.

@example
<pre>
decl myobj = new MyObjective();
decl bhhh = new BHHH(myobj);
bhhh->Iterate();
</pre></dd>

<DT>See <a href="./GetStarted.html">GetStarted</a></DT>

  **/
BHHH::BHHH(O) {	GradientBased(O);	}

/** Create an object of the DFP algorithm.
@param O the `Objective` object to apply this algorithm to.

@example
<pre>
decl myobj = new MyObjective();
decl dfp = new DFP(myobj);
bfgs->Iterate();
</pre></dd>

  **/
DFP::DFP(O)      {
	oxrunerror("FiveO Error 04. DFP not coded  yet");
	GradientBased(O);
	}

/**Create an object of the Newton optimization algorithm.
@param O the `Objective` object to apply this algorithm to.

@example
<pre>
decl myobj = new MyObjective();
decl newt = new Newtown(myobj);
newt->Iterate();
</pre></dd>

@see <a href="./GetStarted.html">GetStarted</a>


 **/
Newton::Newton(O) {	GradientBased(O);	}


/** Compute the direction for the current line search.
If inversion of H fails, reset to I

@return direction vector.
**/
GradientBased::Direction()	{
    decl  l, u, p;
	if (declu(OC.H,&l,&u,&p)==1)
		return solvelu(l,u,p,-OC.G');
	else {
		oxwarning("FiveO Warning 01. Hessian inversion failed.\n Hessian reset to the identify matrix I.\n");
		OC.H = unit(N);
         ++Hresetcnt;
		 return Direction();
		 }
	}

/**  Update the gradient &nabla; f(&psi;).

<DT>This routine is called inside `GradientBased::Iterate`().</DT>
<DD>Creates a copy of the current gradient.</DD>
<DD>Calls `Objective::Gradient`() routine to compute <em>&nabla f(&psi;)</em>, which is (stored internally in `Point::G`).</DD>
<DD>Then computes the size of &nabla; using the built-in Ox <code>norm(m,2)</code> routine.</DD>
<DD>If `Algorithm::Volume` is louder than <code>QUIET</code> <em>&nabla; f()</em> is printed to the screen.</DD>

@return TRUE if &nabla;f(&psi;) &lt; `GradientBased::gradtoler` <br>FALSE otherwise
**/
GradientBased::Gupdate()	{
	oldG = OC.G;
	O->Gradient();	
	deltaG = norm(OC.G,2);
	if (Volume>QUIET) {logf = fopen(lognm,"aV");fprintln(logf,"%r",{"Gradient "},"%c",O.Flabels,OC.G);fclose(logf);}
	return deltaG<gradtoler;
	}

/** Iterate on a gradient-based algorithm.
@param H matrix, initial Hessian<br>integer, use the identity <var>I</Var> as the initial value, or compute H if Newton.

This routine works the <a href="../CFMPI/default.html">CFMPI</a> to execute the parallel task
of computing the gradient.

All gradient-based algorithms conduct a `LineMax`imization on each iteration.

@see  ConvergenceResults

**/
GradientBased::Iterate(H)	{
    decl IamNewt = isclass(this,"Newton"), istr;
	O->Encode();
	N = rows(holdF = OC.F);
    if (!isclass(O.p2p) || O.p2p.IamClient) {  //Only Client Node Iterates

	   if (OC.v==.NaN) O->fobj(0);
       if (IamNewt) {
	     if (isint(H)) O->Hessian();
         else  OC.H = H;
         }
       else
	       OC.H = isint(H) ? unit(N) : H;
	   Hresetcnt = iter =0;
       OC.SE = OC.G = .NaN;
	   if (Volume>SILENT)	{
           logf = fopen(lognm,"aV");
           O->Print("Gradient Starting",logf,Volume>QUIET);
           fclose(logf);
           }
	   if (this->Gupdate())
            convergence=STRONG;         //finished before we start!
	   else do  {                      // HEART OF THE GRADIENT ITERATION

		  holdF = OC.F;
		  LM->Iterate(Direction(),LMitmax);
		  convergence = (++iter>maxiter) ? MAXITERATIONS
                                         : IamNewt ? this->HHupdate(FALSE)
                                                   : (Hresetcnt>1 ? SECONDRESET : this->HHupdate(FALSE)) ;
		  if (Volume>SILENT) {  //Report on Current Iteration
                logf = fopen(lognm,"aV");
                istr = sprint(iter,". f=",OC.v," deltaX: ",deltaX," deltaG: ",deltaG);
                fprintln(logf,istr);
                if(Volume>QUIET) println(istr);
                O->Print("",logf,Volume>QUIET);
                fclose(logf);
                }

		  } while (convergence==NONE);

	     if (Volume>SILENT) {  //Report on Result of Iteration
                logf = fopen(lognm,"aV");
                istr =sprint("\nFinished: ","%1u",convergence,":"+cmsg[convergence],"%c",O.Flabels,"%r",{"    Free Vector","    Gradient"},OC.F'|OC.G);
                fprintln(logf,istr);
                if (Volume>QUIET) println(istr);
                fclose(logf);
                }
	     if (convergence>=WEAK) {
            this->HHupdate(TRUE);
		    OC.SE = sqrt(diagonal(invert(OC.H)));
		    }
	   O->Decode(0);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            O->Print("Gradient Ending",logf,Volume>QUIET);
            fclose(logf);
            }
       if (isclass(O.p2p)) {
            decl reply;
            O.p2p.client->Stop();
            O.p2p.client->Announce(O.cur.X);
            }
       }
    else O.p2p.server->Loop(N);
	}

/**Update the Hessian.
@param FORCE see below.

<DT>This is a wrapper for the virtual `GradientBased::Hupdate`() routine and is called
on each iteration (except possibly the first if convergence is already achieved).</DT>

<DD>Computes the difference in parameter values from this iteration and the last as well
is the norm (both used by `QuasiNewton` algorithms).</DD>
<DD>If <code>FORCE</code> is TRUE, call `GradientBased::Gupdate`() and check both
<code>STRONG</code> and <code>WEAK</code> convergence criteria.</DD>
<DD>Then call the algorithm-specific <code>Hupdate()</code> routine.</DD>

@return the output of <code>Hupdate()</code>

@see   ConvergenceResults

**/
GradientBased::HHupdate(FORCE) {
	deltaX = norm(dx=(OC.F - holdF)',2);
	if (!FORCE)	{
		if (this->Gupdate()) return STRONG;
		if (deltaX<tolerance) return WEAK;
		}
    return this->Hupdate();
	}

/** Default Hessian Update: Steepest Descent, so <var>H f(&psi;)</var> does not change.

Since the default gradient-based algorithm is steepest descent, and since this
algorithm does not use the Hessian, this return does nothing and returns

@return <code>NONE</code>
@see   ConvergenceResults
**/
GradientBased::Hupdate()  {  return NONE;   }

/** Compute the objective's Hessian and the current parameter vector.

@return <code>NONE</CODE>

@see   ConvergenceResults, NoiseLevels

**/
Newton::Hupdate() {
    O->Hessian();
  	if (Volume>QUIET)  println("New Hessian","%c",O.Flabels,"%r",O.Flabels,"%lwr",OC.H);
    return NONE;
    }

/** UPdate the Hessian for the BHHH algorithm.
@return NONE
**/
BHHH::Hupdate() {
   	OC.H = outer(OC.J,<>,'o');
   	if (Volume>NOISY) println("New Hessian","%c",O.Flabels,"%r",O.Flabels,"%lwr",OC.H);
    return NONE;
    }

/** Apply BFGS updating on the Hessian.

<DD>Active Ox code in this routine:
<pre>
decl
  dg = (OC.G - oldG),
  A = double(dx*dg'),
  B = double(outer(dx,OC.H));
  if (fabs(A) < SQRT_EPS*norm(dg,2)*deltaX ) return FAIL;
  OC.H += outer(dg,<>,'o')/A - outer(dx*OC.H,<>,'o')/B;
  return NONE;
</pre>


@return <code>FAIL</CODE> if the updating tolerances are not met.<br>Otherwise <code>NONE</code>

@see   ConvergenceResults, NoiseLevels

**/
BFGS::Hupdate() {
    decl
	   dg = (OC.G - oldG),
	   A = double(dx*dg'),
	   B = double(outer(dx,OC.H));
	if (fabs(A) < SQRT_EPS*norm(dg,2)*deltaX ) return FAIL;
	OC.H += outer(dg,<>,'o')/A - outer(dx*OC.H,<>,'o')/B;
    if (Volume>QUIET) println("New Hessian","%c",array(O.Flabels),"%r",array(O.Flabels),"%lwr",OC.H);
    return NONE;
    }


/** Create a Newton-Raphson object to solve a system of equations.

@param O, the `System`-derived object to solve.

@example
<pre>
obj = new MyObjective();
nr = new NewtonRaphson(obj);
hr -> Iterate();
</pre></dd>

<DT>Also see <a href="GetStarted.html#B">GetStarted</a></DT>

 **/
NewtonRaphson::NewtonRaphson(O) {
	if (!isclass(O,"System")) oxrunerror("FiveO Error 05. Objective must be a System");
	GradientBased(O);
    USELM = FALSE;
	}

/** Create a new Broyden solution for a system of equations.
@param O, the `System`-derived object to solve.

@example
<pre>
obj = new MyObjective();
broy = new Broyden(obj);
broy -> Iterate();
</pre></dd>

<DT>Also see <a href="GetStarted.html#B">GetStarted</a></DT>

**/
Broyden::Broyden(O) {
	if (!isclass(O,"System")) oxrunerror("FiveO Error 06. Objective must be a System");
	GradientBased(O);
    USELM = FALSE;
	}

/** Compute the direction.
If inversion of J fails, reset to I
@return direction
**/
NonLinearSystem::Direction() 	{
	decl  l, u, p;
	if (declu(OC.J,&l,&u,&p)==1) {
		return solvelu(l,u,p,-OC.V);
        }
	else {
		 if (resat) {
		 	println("**** ",OC.F',OC.J,"\n****");
		 	oxrunerror("FiveO Error 07. Second failure to invert J.|n");
			}
		 oxwarning("FiveO Warning 02. NonLinearSystem: J inversion failed. J reset to identity matrix I.\n");
		 OC.J = unit(N);
		 resat = TRUE;
		 return Direction();
		 }
	}

/** Upate gradient when using an aggregation of the system
in a line search.
**/
NonLinearSystem::Gupdate()	{
	oldG = OC.V;
	if (USELM)
         O->fobj(0);
    else
	     O->vobj(0);
	dg = (OC.V - oldG);
	deltaG = norm(OC.V,2);
	return deltaG<gradtoler;
	}

/** Iterate to solve a non-linear system.
@param J matrix, initial Jacobian for Broyden.<br>integer, set to identity

This routine is shared (inherited) by derive algorithms.

**/
NonLinearSystem::Iterate(J)	{
    decl d,istr;
	O->Encode();
	N = rows(holdF = OC.F);
    deltaX=.NaN;
    if (!isclass(O.p2p) || O.p2p.IamClient) {
	   Hresetcnt = iter =0;
	   OC.H = OC.SE = OC.G = .NaN;	
	   resat = FALSE;
	   if (Volume>SILENT)	{
            logf = fopen(lognm,"aV");
            O->Print("Non-linear System Starting",logf,Volume>QUIET);
            fclose(logf);
            }
	   if (this->Gupdate())
            convergence=STRONG;   //Finished before we start!
	   else {
		  if (isclass(this,"Broyden"))
                OC.J =isint(J) ? unit(N) : J;
		  else
		  		O->Jacobian();
	 	  do {

		  	holdF = OC.F;
            d = Direction();
		    if (USELM)
                LM->Iterate(d,LMitmax);
            else
                O->Decode(holdF+d);

			convergence = (++iter>maxiter) ? MAXITERATIONS : (Hresetcnt>1 ? SECONDRESET : this->JJupdate());

			if (Volume>SILENT) {
                logf = fopen(lognm,"aV");
                istr = sprint("\n",iter,".  deltaX: ",deltaX," deltaG:",deltaG,"%c",O.Flabels,"%r",{"    Params Vector","           System","        Direction"},OC.F'|OC.V'|d');
                fprintln(logf,istr);			
                if (Volume>QUIET) println(istr);
                fclose(logf);
                }
			} while (convergence==NONE && !isnan(deltaX) );
		  }

	    O->Decode(0);		
	    if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            istr = sprint("\nConverged:","%1u",convergence,":"+cmsg[convergence],"%c",O.Flabels,"%r",{"    Params Vector","           System"},OC.F'|OC.V');
		    fprintln(logf,istr);
		    if (Volume>QUIET) println(istr);
            O->Print("Non-linear System Ending",logf,Volume>QUIET);
            fclose(logf);
            }
        if (isclass(O.p2p)) {
            O.p2p.client->Stop();
            O.p2p.client->Announce(O.cur.X);
            }
        }
    else O.p2p.server->Loop(N);
	}
	
/** Wrapper for updating the Jacobian of the system.

<DT>This is a wrapper for the virtual `NonLinearSystem::Jupdate`() routine.</DT>

@return <code>FAIL</code> if change in parameter values is too small.
Otherwise, return <code>NONE</code>

@see GradientBased::HHudpate
 **/
NonLinearSystem::JJupdate() {
	decl dx;
	if (this->Gupdate()) return STRONG;
	deltaX = norm(dx=(OC.F - holdF),2);
	if (deltaX<tolerance) return FAIL;
    this->Jupdate(dx);
	return NONE;
	}
	
/** Compute the objective's Jacobian.
@ param dx argument is ignored (default=0)
**/
NonLinearSystem::Jupdate(dx) {O->Jacobian(); }

/** Compute the objective's Jacobian.  **/
NewtonRaphson::Jupdate(dx) { NonLinearSystem::Jupdate(); }

/** Apply Broyden's formula to update the Jacobian.
@param dx x<sub>t+1</sub> - x<sub>t</sub>
**/
Broyden::Jupdate(dx) {OC.J += ((dg-OC.J*dx)/deltaX)*(dx');}

/** Create a new Sequential Quadratic Programming object.
@param O `Constrained` objective
**/
SQP::SQP(O) {
	oxwarning("SQP not working yet!!!!");
	if (isclass(O,"UnConstrained")) oxrunerror("FiveO Error 08. Objective must be Constrained");
	GradientBased(O);	
	ne = OC.eq.N;
	ni = OC.ineq.N;
	}

SQPBFGS::SQPBFGS(O) {
	SQP(O);
	}

/** .  **/
SQP::Hupdate() {
	decl
	   dg = OC.L - oldG,
	   A = double(dx*dg'),
	   B = double(outer(dx,OC.H));
	if (fabs(A) < SQRT_EPS*norm(dg,2)*deltaX ) return FAIL;
//	decl theta = (A>=(1-BETA)*B) ? 1.0 : BETA*B/(B-A),
//	     eta = theta*dg + (1-theta)*OC.H*dx';
//	A  = double(dx*eta');
	OC.H += outer(dg,<>,'o')/A - outer(dx*OC.H,<>,'o')/B;
   	if (Volume>QUIET) println("New Hessian","%c",O.Flabels,"%r",O.Flabels,"%M",OC.H);
    return NONE;
    }
	
/** Iterate.
@param H initial Hessian<br>integer, use I
**/
SQP::Iterate(H)  {
	decl Qconv,deltx,mults,istr;
	O->Encode();
	N = rows(OC.F);
    if (!isclass(O.p2p) || O.p2p.IamClient) {
	   OC.H = isint(H) ? unit(N) : H;
	   OC.SE = OC.G = .NaN;
	   O->Merit(0);
	   if (any(OC.ineq.v.<0)) oxrunerror("FiveO Error 09. Inequality constraints not satisfied at initial psi");
	   if (any(OC.ineq.lam.<0)) oxrunerror("FiveO Error 10. Initial inequality lambda has negative element(s)");
	   if (Volume>SILENT) {
          logf = fopen(lognm,"aV");
          O->Print("SQP Starting",logf,Volume>QUIET);
		  fprintln(logf," .f0=",OC.v,". #Equality: ",ne,". #InEquality: ",ni);	
          fclose(logf);
          }	
	   Hresetcnt = iter =0;
	   do  {
		  holdF = OC.F;
		  this->Gupdate();
		  [Qconv,deltx,mults] = SolveQP(OC.H,OC.L',OC.ineq.J,OC.ineq.v,OC.eq.J,OC.eq.v,<>,<>);  // -ineq or +ineq?
		  if (ne) OC.eq.lam =  mults[:ne-1];
		  if (ni) OC.ineq.lam =  mults[ne:];
		  LM->Iterate(deltx,1);
		  convergence = (++iter>maxiter) ? MAXITERATIONS : (Hresetcnt>1 ? SECONDRESET : this->HHupdate(FALSE));		
		  if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            istr = sprint("\n",iter,". convergence:",convergence,". QP code:",Qconv,". L=",OC.v," deltaX: ",deltaX," deltaG: ",deltaG);
		    fprintln(logf,istr);
            if (Volume>QUIET) println(istr);
			OC.eq->print();
			OC.ineq->print();
            fclose(logf);
			}
		  } while (convergence==NONE);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            fprintln(logf,"\nConverged: ","%1u",convergence,":"+cmsg[convergence],"%c",O.Flabels,"%r",{"    Free Vector","    Gradient"},OC.F'|OC.G);
            OC.eq->print();
            OC.ineq->print();
            fclose(logf);
		    }
	   if (convergence>=WEAK) {
		  this->HHupdate(TRUE);
		  OC.SE = sqrt(diagonal(invert(OC.H)));
		  }
	   O->Decode(0);
	   if (Volume>SILENT) {
            logf = fopen(lognm,"aV");
            O->Print("SQP Ending",logf,Volume>QUIET);
            fclose(logf);
            }
       if (isclass(O.p2p)) {
            O.p2p.client->Stop();
            O.p2p.client->Announce(O.cur.X);
            }
       }
    else O.p2p.server->Loop(N);
	}

/** .
**/
SQP::Gupdate() {
	O->Gradient();
	oldG = OC.L;
	OC.L  = OC.G-(ni ? OC.ineq.lam'*OC.ineq.J : 0.0)-(ne ? OC.eq.lam'*OC.eq.J : 0.0);
	deltaG = norm(OC.L,2);
	}
	
/** .
**/
SQP::HHupdate(FORCE) {
	deltaX = norm(dx=(OC.F - holdF)',2);
	if (!FORCE)	{
		this->Gupdate();
		if (deltaX<tolerance) return STRONG;
		}
    return this->Hupdate();
	}
