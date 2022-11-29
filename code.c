/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*COMPILADORES
*/

#include "hoc.h"
#include "y.tab.h"
#include <stdio.h>

#define	NSTACK	2048

static Datum stack[NSTACK];	/* La pila */
static Datum *stackp;		/* Siguiete espacio disponible en la pila */

#define	NPROG	2000
Inst	prog[NPROG];	/* La maquina */
Inst	*progp;		/* siguiente espacio libre para la generacion de codigo*/
Inst	*pc;		/* contador de programa*/
Inst	*progbase = prog; 
int	returning;	
extern int	indef;	

//Controla el mensaje en LOG
extern char msj[300];

typedef struct Frame {	/* proc/func call stack frame */
	Symbol	*sp;	/* symbol table entry */
	Inst	*retpc;	/* where to resume after return */
	Datum	*argn;	/* n-th argument on stack */
	int	nargs;	/* number of arguments */
} Frame;
#define	NFRAME	100
Frame	frame[NFRAME];
Frame	*fp;		/* frame pointer */

void
initcode(void)
{
	progp = progbase;
	stackp = stack;
	fp = frame;
	returning = 0;
	indef = 0;
}

void
push(Datum d)
{
	if (stackp >= &stack[NSTACK])
		execerror("stack too deep", 0);
	*stackp++ = d;
}

Datum
pop(void)
{
	if (stackp == stack)
		execerror("stack underflow", 0);
	return *--stackp;
}

void
xpop(void)	/* for when no value is wanted */
{
	if (stackp == stack)
		execerror("stack underflow", (char *)0);
	--stackp;
}

void
constpush(void)
{
	
	Datum d;
	d.val = ((Symbol *)*pc++)->u.val;
	push(d);
}

void
varpush(void)
{
	
	Datum d;
	d.sym = (Symbol *)(*pc++);
	push(d);
}

void
whilecode(void)
{
	
	Datum d;
	Inst *savepc = pc;

	execute(savepc+2);	/* condition */
	d = pop();
	while (d.val) {
		execute(*((Inst **)(savepc)));	/* body */
		if (returning)
			break;
		execute(savepc+2);	/* condition */
		d = pop();
	}
	if (!returning)
		pc = *((Inst **)(savepc+1)); /* next stmt */
}

void
forcode(void)
{
	
	Datum d;
	Inst *savepc = pc;

	execute(savepc+4);		/* precharge */
	pop();
	execute(*((Inst **)(savepc)));	/* condition */
	d = pop();
	while (d.val) {
		execute(*((Inst **)(savepc+2)));	/* body */
		if (returning)
			break;
		execute(*((Inst **)(savepc+1)));	/* post loop */
		pop();
		execute(*((Inst **)(savepc)));	/* condition */
		d = pop();
	}
	if (!returning)
		pc = *((Inst **)(savepc+3)); /* next stmt */
}

void
ifcode(void) 
{
	
	Datum d;
	Inst *savepc = pc;	/* then part */

	execute(savepc+3);	/* condition */
	d = pop();
	if (d.val)
		execute(*((Inst **)(savepc)));	
	else if (*((Inst **)(savepc+1))) /* else part? */
		execute(*((Inst **)(savepc+1)));
	if (!returning)
		pc = *((Inst **)(savepc+2)); /* next stmt */
}

void
define(Symbol* sp)	/* put func/proc in symbol table */
{
	sp->u.defn = progbase;	/* start of code */
	progbase = progp;	/* next code starts here */
}

void
call(void) 		/* call a function */
{
	Symbol *sp = (Symbol *)pc[0]; /* symbol table entry */
				      /* for function */
	if (fp++ >= &frame[NFRAME-1])
		execerror(sp->name, "call nested too deeply");
	fp->sp = sp;
	fp->nargs = (int)pc[1];
	fp->retpc = pc + 2;
	fp->argn = stackp - 1;	/* last argument */
	execute(sp->u.defn);
	returning = 0;
}

static void
ret(void) 		/* common return from func or proc */
{
	int i;
	for (i = 0; i < fp->nargs; i++)
		pop();	/* pop arguments */
	pc = (Inst *)fp->retpc;
	--fp;
	returning = 1;
}

void
funcret(void) 	/* return from a function */
{
	Datum d;
	if (fp->sp->type == PROCEDURE)
		execerror(fp->sp->name, "(proc) returns value");
	d = pop();	/* preserve function return value */
	ret();
	push(d);
}

void
procret(void) 	/* return from a procedure */
{
	if (fp->sp->type == FUNCTION)
		execerror(fp->sp->name,
			"(func) returns no value");
	ret();
}

double*
getarg(void) 	/* return pointer to argument */
{
	int nargs = (int) *pc++;
	if (nargs > fp->nargs)
	    execerror(fp->sp->name, "not enough arguments");
	return &fp->argn[nargs - fp->nargs].val;
}

void
arg(void) 	/* push argument onto stack */
{
	Datum d;
	d.val = *getarg();
	push(d);
}

void
argassign(void) 	/* store top of stack in argument */
{
	Datum d;
	d = pop();
	push(d);	/* leave value on stack */
	*getarg() = d.val;
}

void
argaddeq(void) 	/* store top of stack in argument */
{
	Datum d;
	d = pop();
	d.val = *getarg() += d.val;
	push(d);	/* leave value on stack */
}

void
argsubeq(void) 	/* store top of stack in argument */
{
	Datum d;
	d = pop();
	d.val = *getarg() -= d.val;
	push(d);	/* leave value on stack */
}

void
argmuleq(void) 	/* store top of stack in argument */
{
	Datum d;
	d = pop();
	d.val = *getarg() *= d.val;
	push(d);	/* leave value on stack */
}

void
argdiveq(void) 	/* store top of stack in argument */
{
	Datum d;
	d = pop();
	d.val = *getarg() /= d.val;
	push(d);	/* leave value on stack */
}

void
argmodeq(void) 	/* store top of stack in argument */
{
	Datum d;
	double *x;
	long y;
	d = pop();
	/* d.val = *getarg() %= d.val; */
	x = getarg();
	y = *x;
	d.val = *x = y % (long) d.val;
	push(d);	/* leave value on stack */
}

void
bltin(void) 
{

	Datum d;
	d = pop();
	d.val = (*(double (*)(double))*pc++)(d.val);
	push(d);
}

void
add(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val += d2.val;
	push(d1);
}

void
sub(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val -= d2.val;
	push(d1);
}

void
mul(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val *= d2.val;
	push(d1);
}

void
divop(void)
{
	
	Datum d1, d2;
	d2 = pop();
	if (d2.val == 0.0)
		execerror("division by zero", (char *)0);
	d1 = pop();
	d1.val /= d2.val;
	push(d1);
}

void
mod(void)
{
	
	Datum d1, d2;
	long x;
	d2 = pop();
	if (d2.val == 0.0)
		execerror("division by zero", (char *)0);
	d1 = pop();
	/* d1.val %= d2.val; */
	x = d1.val;
	x %= (long) d2.val;
	d1.val = d2.val = x;
	push(d1);
}

void
negate(void)
{
	
	Datum d;
	d = pop();
	d.val = -d.val;
	push(d);
}

void
verify(Symbol* s)
{
	if (s->type != VAR && s->type != UNDEF)
		execerror("attempt to evaluate non-variable", s->name);
	if (s->type == UNDEF)
		execerror("undefined variable", s->name);
}

void
eval(void)		/* Evalua una variable ne la pila */
{
	
	Datum d;
	d = pop();
	verify(d.sym);
	d.val = d.sym->u.val;
	push(d);
}

void
preinc(void)
{
	
	Datum d;
	d.sym = (Symbol *)(*pc++);
	verify(d.sym);
	d.val = d.sym->u.val += 1.0;
	push(d);
}

void
predec(void)
{
	
	Datum d;
	d.sym = (Symbol *)(*pc++);
	verify(d.sym);
	d.val = d.sym->u.val -= 1.0;
	push(d);
}

void
postinc(void)
{
	
	Datum d;
	double v;
	d.sym = (Symbol *)(*pc++);
	verify(d.sym);
	v = d.sym->u.val;
	d.sym->u.val += 1.0;
	d.val = v;
	push(d);
}

void
postdec(void)
{
	
	Datum d;
	double v;
	d.sym = (Symbol *)(*pc++);
	verify(d.sym);
	v = d.sym->u.val;
	d.sym->u.val -= 1.0;
	d.val = v;
	push(d);
}

void
gt(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val > d2.val);
	push(d1);
}

void
lt(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val < d2.val);
	push(d1);
}

void
ge(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val >= d2.val);
	push(d1);
}

void
le(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val <= d2.val);
	push(d1);
}

void
eq(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val == d2.val);
	push(d1);
}

void
ne(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val != d2.val);
	push(d1);
}

void
and(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val != 0.0 && d2.val != 0.0);
	push(d1);
}

void
or(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = (double)(d1.val != 0.0 || d2.val != 0.0);
	push(d1);
}

void
not(void)
{
	
	Datum d;
	d = pop();
	d.val = (double)(d.val == 0.0);
	push(d);
}

void
power(void)
{
	
	Datum d1, d2;
	d2 = pop();
	d1 = pop();
	d1.val = Pow(d1.val, d2.val);
	push(d1);
}

void
assign(void)
{
	
	Datum d1, d2;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	d1.sym->u.val = d2.val;
	d1.sym->type = VAR;
	push(d2);
}

void
addeq(void)
{
	Datum d1, d2;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	d2.val = d1.sym->u.val += d2.val;
	d1.sym->type = VAR;
	push(d2);
}

void
subeq(void)
{
	Datum d1, d2;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	d2.val = d1.sym->u.val -= d2.val;
	d1.sym->type = VAR;
	push(d2);
}

void
muleq(void)
{
	Datum d1, d2;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	d2.val = d1.sym->u.val *= d2.val;
	d1.sym->type = VAR;
	push(d2);
}

void
diveq(void)
{
	Datum d1, d2;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	d2.val = d1.sym->u.val /= d2.val;
	d1.sym->type = VAR;
	push(d2);
}

void
modeq(void)
{
	Datum d1, d2;
	long x;
	d1 = pop();
	d2 = pop();
	if (d1.sym->type != VAR && d1.sym->type != UNDEF)
		execerror("assignment to non-variable",
			d1.sym->name);
	/* d2.val = d1.sym->u.val %= d2.val; */
	x = d1.sym->u.val;
	x %= (long) d2.val;
	d2.val = d1.sym->u.val = x;
	d1.sym->type = VAR;
	push(d2);
}

void
printtop(void)	/* Saca un valor de la pila y lo imprime */
{
	Datum d;
	static Symbol *s;	/* ultimo valor calculado*/
	if (s == 0)
		s = install("_", VAR, 0.0);
	d = pop();
	printf("%.*g\n", (int)lookup("PREC")->u.val, d.val);
	s->u.val = d.val;
}

void
prexpr(void)	/* imprime valor numerico */
{
	Datum d;
	d = pop();
	printf("%.*g ", (int)lookup("PREC")->u.val, d.val);
}

void
prstr(void)		/* imprime una cadena */ 
{
	printf("%s", (char *) *pc++);
}

void
varread(void)	/* Lee una variable  */
{
	Datum d;
	extern FILE *fin;
	Symbol *var = (Symbol *) *pc++;
  Again:
	switch (fscanf(fin, "%lf", &var->u.val)) {
	case EOF:
		if (moreinput())
			goto Again;
		d.val = var->u.val = 0.0;
		break;
	case 0:
		execerror("non-number read into", var->name);
		break;
	default:
		d.val = 1.0;
		break;
	}
	var->type = VAR;
	push(d);
}

Inst*
code(Inst f)	/* Agrega una instruccion u operando */
{
	Inst *oprogp = progp;
	if (progp >= &prog[NPROG])
		execerror("program too big", (char *)0);
	*progp++ = f;
	return oprogp;
}

void
execute(Inst* p)
{
	
	for (pc = p; *pc != STOP && !returning; )
		(*((++pc)[-1]))();
	
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

/* LOGO */
extern struct nodo {
        float x; //punto x inicial
        float y; //punto y inicial
        float dx; //punto en x final
        float dy; //punto en y final
        char penup_pendown;
        float r,g,b;
        struct nodo *sig;
    };

/*
* Instruccion para avanzar n
* Toma el valor n de la pila y agrega un punto en la direccion del
* angulo acutual
**/
void fd(){

    
    Datum fd_pos;
    fd_pos = pop();
    
    float x = fd_pos.val*cos(angulo * 3.14159265f / 180.0f);
    float y = fd_pos.val*sin(angulo * 3.14159265f / 180.0f);
    insertar( fondo->dx, fondo->dy, x, -y , pup_pdown, fondo->r, fondo->g, fondo->b);
    snprintf(msj, sizeof msj, "Avanzar %0.2f unidades, angulo de %0.2f°", fd_pos.val, angulo );
}

/*
* Instruccion para retroceder n
* Toma el valor n de la pila y agrega un punto en la direccion del
* angulo acutual
**/
void bk(){
    
    Datum bk_pos;
    bk_pos = pop();
    
    float x = bk_pos.val*cos(angulo * 3.14159265f / 180.0f);
    float y = bk_pos.val*sin(angulo * 3.14159265f / 180.0f);
    insertar( fondo->dx, fondo->dy, -x, y , pup_pdown, fondo->r, fondo->g, fondo->b);
    snprintf(msj, sizeof msj, "Retorceder %0.2f unidades, angulo de %0.2f°", bk_pos.val, angulo );
}

//Rota el angulo en direccion de las manecillas del reloj
void rt(){
    
    Datum ang;
    ang = pop();
    angulo = fmod( (angulo - ang.val), 360 );
    if(angulo < 0 )
        angulo = 360 + angulo;
    snprintf(msj, sizeof msj, "Rotar %0.2f, angulo de %0.2f° establecido", ang.val, angulo );
}

//Rota el angulo en direccion contraria a las mancillas del reloj 
void lta(){
    
    
    Datum ang;
    ang = pop();
    angulo = fmod( (angulo + ang.val), 360 );
    snprintf(msj, sizeof msj, "Rotar %0.2f, angulo de %0.2f° establecido", ang.val, angulo );
}

/*
* Instruccion para centrar la tortuga
* Agrega un punto en el centro del area de dibujo, este sera el
* punto de partida para continuar dibujando
**/
void ct(){
    
    angulo = 90;
    insertar(0,0,0,0, pup_pdown, fondo->r, fondo->g, fondo->b);
    snprintf(msj, sizeof msj, "Centrar, angulo de %0.2f° establecido", angulo );
}

/*
* Instruccion para limpiar la ventana
* Llama a la instruccion eliminar que limpia la cola con los puntos
**/
void cs(){
    
    eliminar();
    snprintf(msj, sizeof msj, "Ventana limpiada" );
}

/*
* Instruccion para levantar la pluma
* establece la variable pop_pdow en 0 por lo tanto los puntos
* tendran el canal alfa en 0 por lo que el color no sera visible
**/
void penup(){
    
    snprintf(msj, sizeof msj, "Lapiz levantado");
    pup_pdown = 0;
}

/*
* Instruccion para colocar la pluma
* establece la variable pop_pdow en 1 por lo tanto los puntos
* tendran el canal alfa en 1 por lo que el color sera visible
**/
void pendown(){
    
    snprintf(msj, sizeof msj, "Lapiz colocado" );
    pup_pdown = 1;
}

/*
* Instruccion para establecer un angulo
* El valor del nuevo angulo estara en el tope de la pila
* este angulo debe de estar entre 0 - 360 por lo que se
* realizar la operacion modulo
**/
void sethang(){
    
    //En numero para el angulo estan en la pila
    Datum d;
    d = pop();
    angulo = fmod( d.val, 360 );
    
    snprintf(msj, sizeof msj, "Angulo de %0.2f establecido", angulo );
}

/*
* Instruccion para cambiar el color de la pluma
* Los 3 valores para el color estaran en la pila
* Se inserta un punto en la posicion actual y se establece
* el nuevo color
**/
void pcolor(){
    
    //Los 3 valores para el color estan en la pila
    Datum col;
    float r,g,b;

    col = pop();
    b = col.val/255;

    col = pop();
    g = col.val/255;
    
    col = pop();
    r = col.val/255;

    snprintf(msj, sizeof msj, "Nuevo color establecido" );
    insertar(fondo->dx,fondo->dy,0,0, fondo->penup_pendown, r, g, b);
}

/*
* Instruccion para repetir comandos n veces
* El número de repeticiones estará en la pila
* Se toma el valor de n y se ejecutan los comandos almacenados
* en stmt n veces
**/
void repeata(){
    

    Datum d;
    Inst *savepc = pc;
    int i = 0;

    execute( savepc+2 );
    d = pop(); //Se saca el numero de repeticiones de la pila
    

    for( i = 0; i<d.val; i++ ){
        execute( *((Inst **)(savepc)) ); //Se ejecuta stmt
        if( returning )
            break;
    }

    if(!returning)
        pc = *((Inst **)(savepc + 1)); //Siguiente linea
}

