/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*COMPILADORES
*/
#include <math.h>
#include <errno.h>
extern	int	errno;
double	errcheck();

#include "hoc.h"

double	errcheck(double, char*);

double
Log(double x)
{
	return errcheck(log(x), "log");
}
double
Log10(double x)
{
	return errcheck(log10(x), "log10");
}

double
Sqrt(double x)
{
	return errcheck(sqrt(x), "sqrt");
}

double
Gamma(double x)
{
	double y;
	extern int signgam;
	y=errcheck(gamma(x), "gamma");
	if(y>88.0)
		execerror("gamma result out of range", (char *)0);
	return signgam*exp(y);
}

double
Exp(double x)
{
	return errcheck(exp(x), "exp");
}

double
Asin(double x)
{
	return errcheck(asin(x), "asin");
}

double
Acos(double x)
{
	return errcheck(acos(x), "acos");
}

double
Sinh(double x)
{
	return errcheck(sinh(x), "sinh");
}
double
Cosh(double x)
{
	return errcheck(cosh(x), "cosh");
}
double
Pow(double x, double y)
{
	return errcheck(pow(x,y), "exponentiation");
}

double
integer(double x)
{
	return (double)(long)x;
}

double
errcheck(double d, char* s)	/* check result of library call */
{
	if (errno == EDOM) {
		errno = 0;
		execerror(s, "argument out of domain");
	} else if (errno == ERANGE) {
		errno = 0;
		execerror(s, "result out of range");
	}
	return d;
}
