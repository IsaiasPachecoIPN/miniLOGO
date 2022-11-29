%{

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*COMPILADORES
*/

#include <string.h>
#include "hoc.h"
#include <cairo.h>
#include <gtk/gtk.h>

    //Estructura que contiene los puntos para pinta
    struct nodo {
        float x; //punto x inicial
        float y; //punto y inicial
        float dx; //punto x final
        float dy; //punto  y final
        char penup_pendown;
        float r,g,b;
        struct nodo *sig;
    };

    //variable global que apunta al primer elemento de la cola
    struct nodo *raiz=NULL;
    
    //Variable global que apunta al fondo de la cola
    struct nodo *fondo=NULL;

    //Regresar al inicio

    struct nodo *inicioPuntos;

    //Variable global que cuenta los elementos en la cola
    int counter = 0;

    //variable global para controlar la pintada
    float angulo = 90;

    //Variable global para controlar el mensaje de comando
    char msj[100] = "...";

    //Variable global que controla la pluma penup/pendown
    char pup_pdown = 1;

    double escalaX = 1;

    unsigned char cargar_demo = 1;

#define	code2(c1,c2)	code(c1); code(c2)
#define	code3(c1,c2,c3)	code(c1); code(c2); code(c3)
int	indef;
void yyerror(char* s);
%}
%union {
	Symbol	*sym;	/* symbol table pointer */
	Inst	*inst;	/* machine instruction */
	int	narg;	/* number of arguments */
}
%token	<sym>	NUMBER STRING PRINT VAR BLTIN UNDEF WHILE FOR IF ELSE
%token  <sym>   FD BK RT LTA CT CS REPEATA PENUP PENDOWN END SETHA PENC//Tokens para LOGO
%token	<sym>	FUNCTION PROCEDURE RETURN FUNC PROC READ
%token	<narg>	ARG
%type	<inst>	expr stmt asgn prlist stmtlist
%type	<inst>	cond while for if begin end 
%type	<inst>  repeat  logocomand//LOGO
%type	<sym>	procname
%type	<narg>	arglist
%right	'=' ADDEQ SUBEQ MULEQ DIVEQ MODEQ
%left	OR
%left	AND
%left	GT GE LT LE EQ NE
%left	'+' '-'
%left	'*' '/' '%'
%left	UNARYMINUS NOT INC DEC
%right	'^'
%%
list:	  /* nothing */
	| list '\n'
	| list defn '\n'
	| list asgn '\n'  { code2(xpop, STOP); return 1; }
	| list stmt '\n'  { code(STOP); return 1; } 
	| list expr '\n'  { code(STOP); return 1; }
	| list error '\n' { yyerrok; }
	;
asgn:	  VAR '=' expr { code3(varpush,(Inst)$1,assign); $$=$3; }
	| VAR ADDEQ expr	{ code3(varpush,(Inst)$1,addeq); $$=$3; }
	| VAR SUBEQ expr	{ code3(varpush,(Inst)$1,subeq); $$=$3; }
	| VAR MULEQ expr	{ code3(varpush,(Inst)$1,muleq); $$=$3; }
	| VAR DIVEQ expr	{ code3(varpush,(Inst)$1,diveq); $$=$3; }
	| VAR MODEQ expr	{ code3(varpush,(Inst)$1,modeq); $$=$3; }
	| ARG '=' expr   { defnonly("$"); code2(argassign,(Inst)$1); $$=$3;}
	| ARG ADDEQ expr { defnonly("$"); code2(argaddeq,(Inst)$1); $$=$3;}
	| ARG SUBEQ expr { defnonly("$"); code2(argsubeq,(Inst)$1); $$=$3;}
	| ARG MULEQ expr { defnonly("$"); code2(argmuleq,(Inst)$1); $$=$3;}
	| ARG DIVEQ expr { defnonly("$"); code2(argdiveq,(Inst)$1); $$=$3;}
	| ARG MODEQ expr { defnonly("$"); code2(argmodeq,(Inst)$1); $$=$3;}
	;
stmt:	  expr	{  }
	| RETURN { defnonly("return"); code(procret); }
	| RETURN expr
	        { defnonly("return"); $$=$2; code(funcret); }
	| PROCEDURE begin '(' arglist ')'
		{ $$ = $2; code3(call, (Inst)$1, (Inst)$4); }
	| PRINT prlist	{ $$ = $2; }
	| while '(' cond ')' stmt end {
		($1)[1] = (Inst)$5;	/* stmr */
		($1)[2] = (Inst)$6; }	/* final del ciclo  */
	| for '(' cond ';' cond ';' cond ')' stmt end {
		($1)[1] = (Inst)$5;	/* condicion */
		($1)[2] = (Inst)$7;	/* actualizacion */
		($1)[3] = (Inst)$9;	/* stmt */
		($1)[4] = (Inst)$10; }	/* final del ciclo */
	| repeat ':' cond stmt end {
		($1)[1] = (Inst)$4;   /* stmr */
		($1)[2] = (Inst)$5;   /* end */
							 }
	| if '(' cond ')' stmt end {	/* else-less if */
		($1)[1] = (Inst)$5;	/* thenpart */
		($1)[3] = (Inst)$6; }	/* end, if cond fails */
	| if '(' cond ')' stmt end ELSE stmt end {	/* if with else */
		($1)[1] = (Inst)$5;	/* thenpart */
		($1)[2] = (Inst)$8;	/* elsepart */
		($1)[3] = (Inst)$9; }	/* end, if cond fails */
	| '{' stmtlist '}'	{ $$ = $2; }
	;

cond:	   expr 	{ code(STOP); }
	;
while:	  WHILE	{ $$ = code3(whilecode,STOP,STOP); }
	;
for:	  FOR	{ $$ = code(forcode); code3(STOP,STOP,STOP); code(STOP); }
	;
repeat:   REPEATA  { $$ = code3(repeata,STOP,STOP);  }
	;

if:	  IF	{ $$ = code(ifcode); code3(STOP,STOP,STOP); }
	;
begin:	  /* nothing */		{ $$ = progp; }
	;
end:	  /* nothing */		{ code(STOP); $$ = progp; }
	;
stmtlist: /* nothing */		{ $$ = progp; }
	| stmtlist '\n'
	| stmtlist stmt
	;
expr:	  NUMBER { $$ = code2(constpush, (Inst)$1); }
	| VAR	 { $$ = code3(varpush, (Inst)$1, eval); }
	| ARG	 { defnonly("$"); $$ = code2(arg, (Inst)$1); }
	| asgn
	| FUNCTION begin '(' arglist ')'
		{ $$ = $2; code3(call,(Inst)$1,(Inst)$4); }
	| READ '(' VAR ')' { $$ = code2(varread, (Inst)$3); }
	| BLTIN '(' expr ')' { $$=$3; code2(bltin, (Inst)$1->u.ptr); }
	| '(' expr ')'	{ $$ = $2; }
	| expr '+' expr	{ code(add); }
	| expr '-' expr	{ code(sub); }
	| expr '*' expr	{ code(mul); }
	| expr '/' expr	{ code(divop); }	/* ansi has a div fcn! */
	| expr '%' expr	{ code(mod); }
	| expr '^' expr	{ code (power); }
	| '-' expr   %prec UNARYMINUS   { $$=$2; code(negate); }
	| expr GT expr	{ code(gt); }
	| expr GE expr	{ code(ge); }
	| expr LT expr	{ code(lt); }
	| expr LE expr	{ code(le); }
	| expr EQ expr	{ code(eq); }
	| expr NE expr	{ code(ne); }
	| expr AND expr	{ code(and); }
	| expr OR expr	{ code(or); }
	| NOT expr	{ $$ = $2; code(not); }
	| INC VAR	{ $$ = code2(preinc,(Inst)$2); }
	| DEC VAR	{ $$ = code2(predec,(Inst)$2); }
	| VAR INC	{ $$ = code2(postinc,(Inst)$1); }
	| VAR DEC	{ $$ = code2(postdec,(Inst)$1); }
	| logocomand
	;

logocomand:FD 	expr        { code(fd);  }
	|BK 	expr            { code(bk);  }
	|RT 	expr            { code(rt);  }
	|LTA	expr            { code(lta); }
	|CT                     { code(ct);  }
	|CS                     { code(cs);  }
	|PENUP                  { $$ = code(penup);   }
    |PENDOWN                { $$ = code(pendown); }
    |SETHA expr             { $$ = code(sethang); }
    |PENC  expr expr expr   { $$ = code(pcolor);  }
    ;
	
prlist:	  expr			{ code(prexpr); }
	| STRING		{ $$ = code2(prstr, (Inst)$1); }
	| prlist ',' expr	{ code(prexpr); }
	| prlist ',' STRING	{ code2(prstr, (Inst)$3); }
	;
defn:	  FUNC procname { $2->type=FUNCTION; indef=1; }
	    '(' ')' stmt { code(procret); define($2); indef=0; }
	| PROC procname { $2->type=PROCEDURE; indef=1; }
	    '(' ')' stmt { code(procret); define($2); indef=0; }
	;
procname: VAR
	| FUNCTION
	| PROCEDURE
	;
arglist:  /* nothing */ 	{ $$ = 0; }
	| expr			{ $$ = 1; }
	| arglist ',' expr	{ $$ = $1 + 1; }
	;
%%
	/* end of grammar */
#include <stdio.h>
#include <ctype.h>
char	*progname;
int	lineno = 1;
#include <signal.h>
#include <setjmp.h>
#include <errno.h>
jmp_buf	begin;
char	*infile;	/* input file name */
FILE	*fin;		/* input file pointer */
char	**gargv;	/* global argument list */
extern	errno;
int	gargc;

int c = '\n';	/* global for use by warning() */

//Estructura para los puntos
void insertar(float x, float y, float dx, float dy, char penup_pendown , float r, float g, float b );
struct nodo * getPunto();
int vacia();
void imprimir();
void eliminar();
//GUI
//LLamada a GTK cairo
//static void activate (GtkApplication* app, gpointer user_data);

//Dibujo actual
static gboolean on_draw_event( GtkWidget *widget, cairo_t *cr, gpointer user_data);

//do_drawing se encarga de pintar
static void do_drawing( cairo_t *cr );

//evento del boton
static void callback( GtkWidget *widget, gpointer   data );
static void incrementarEscala( GtkWidget *widget, gpointer   data );
static void decrementarEscala( GtkWidget *widget, gpointer   data );

//Carga de estilos css
static void cargarCSS();

//Manejar eventos del teclado
static gboolean my_keypress_function (GtkWidget *widget, GdkEventKey *event, gpointer data);

//Cargar la interfaz grafica
static void cargarGUI();

int ancho, alto, altowindow;

float dxWindow = 0;
float dyWindow = 0;

char *get_text_of_textview(GtkWidget *text_view);

int	backslash(int), follow(int, int, int);
void	defnonly(char*), run(void);
void	warning(char*, char*);

yylex(void)		/* hoc6 */
{
	while ((c=getc(fin)) == ' ' || c == '\t')
		;
	if (c == EOF)
		return 0;
	if (c == '\\') {
		c = getc(fin);
		if (c == '\n') {
			lineno++;
			return yylex();
		}
	}
	if (c == '#') {		/* comment */
		while ((c=getc(fin)) != '\n' && c != EOF)
			;
		if (c == '\n')
			lineno++;
		return c;
	}
	if (c == '.' || isdigit(c)) {	/* number */
		double d;
		ungetc(c, fin);
		fscanf(fin, "%lf", &d);
		yylval.sym = install("", NUMBER, d);
		return NUMBER;
	}
	if (isalpha(c) || c == '_') {
		Symbol *s;
		char sbuf[100], *p = sbuf;
		do {
			if (p >= sbuf + sizeof(sbuf) - 1) {
				*p = '\0';
				execerror("name too long", sbuf);
			}
			*p++ = c;
		} while ((c=getc(fin)) != EOF && (isalnum(c) || c == '_'));
		ungetc(c, fin);
		*p = '\0';
		if ((s=lookup(sbuf)) == 0)
			s = install(sbuf, UNDEF, 0.0);
		yylval.sym = s;
		return s->type == UNDEF ? VAR : s->type;
	}
	if (c == '$') {	/* argument? */
		int n = 0;
		while (isdigit(c=getc(fin)))
			n = 10 * n + c - '0';
		ungetc(c, fin);
		if (n == 0)
			execerror("strange $...", (char *)0);
		yylval.narg = n;
		return ARG;
	}
	if (c == '"') {	/* quoted string */
		char sbuf[100], *p;
		for (p = sbuf; (c=getc(fin)) != '"'; p++) {
			if (c == '\n' || c == EOF)
				execerror("missing quote", "");
			if (p >= sbuf + sizeof(sbuf) - 1) {
				*p = '\0';
				execerror("string too long", sbuf);
			}
			*p = backslash(c);
		}
		*p = 0;
		yylval.sym = (Symbol *)emalloc(strlen(sbuf)+1);
		strcpy((char*)yylval.sym, sbuf);
		return STRING;
	}
	switch (c) {
	case '+':	return follow('+', INC, follow('=', ADDEQ, '+'));
	case '-':	return follow('-', DEC, follow('=', SUBEQ, '-'));
	case '*':	return follow('=', MULEQ, '*');
	case '/':	return follow('=', DIVEQ, '/');
	case '%':	return follow('=', MODEQ, '%');
	case '>':	return follow('=', GE, GT);
	case '<':	return follow('=', LE, LT);
	case '=':	return follow('=', EQ, '=');
	case '!':	return follow('=', NE, NOT);
	case '|':	return follow('|', OR, '|');
	case '&':	return follow('&', AND, '&');
	case '\n':	lineno++; return '\n';
	default:	return c;
	}
}

backslash(int c)	/* get next char with \'s interpreted */
{
	static char transtab[] = "b\bf\fn\nr\rt\t";
	if (c != '\\')
		return c;
	c = getc(fin);
	if (islower(c) && strchr(transtab, c))
		return strchr(transtab, c)[1];
	return c;
}

follow(int expect, int ifyes, int ifno)	/* look ahead for >=, etc. */
{
	int c = getc(fin);

	if (c == expect)
		return ifyes;
	ungetc(c, fin);
	return ifno;
}

void
yyerror(char* s)	/* report compile-time error */
{
/*rob
	warning(s, (char *)0);
	longjmp(begin, 0);
rob*/
	execerror(s, (char *)0);
}

void
execerror(char* s, char* t)	/* recover from run-time error */
{
	warning(s, t);
	fseek(fin, 0L, 2);		/* flush rest of file */
	longjmp(begin, 0);
}

void
fpecatch(int signum)	/* catch floating point exceptions */
{
	execerror("floating point exception", (char *) 0);
}

void
intcatch(int signum)	/* catch interrupts */
{
	execerror("interrupt", (char *) 0);
}

void
run(void)	/* execute until EOF */
{
	setjmp(begin);
	signal(SIGINT, intcatch);
	signal(SIGFPE, fpecatch);
	for (initcode(); yyparse(); initcode())
		execute(progbase);
}

int
main(int argc, char* argv[])	/* hoc6 */
{
	static int first = 1;
#if YYDEBUG
	yydebug=3;
#endif
	progname = argv[0];
	init();

	//Punto inicial para iniciar a pintar
    insertar(0,0,0,0,1, 70/255, 130/255, 180/255);
    raiz->penup_pendown = 0;

	//Tamaño de ventana
    ancho = 800;
    alto  = 500;
    altowindow = 900;

	if (argc == 1) {	/* fake an argument list */
		static char *stdinonly[] = { "-" };

		gargv = stdinonly;
		gargc = 1;
	} else if (first) {	/* for interrupts */
		first = 0;
		gargv = argv+1;
		gargc = argc-1;
	}

    /*Cargar demo */
    while( demo() )
        run();
    gargc = 1;
    initcode();

    /* Cargar interfaz gŕafica*/
	cargarGUI();
	return 0;
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

int moreinput(){
    /*
    * El archivo test.txt contendra los comandos
    * por lo que se debe de realizar el análisis
    * sobre este
    */
    if( gargc-- <= 0)
        return 0;
    if ( fin && fin != stdin )
        fclose(fin);
    infile = *gargv++;
    lineno = 1;
     if ( (fin = fopen("test.txt", "r")) == NULL ) {
        fprintf( stderr, "%s: cant open %s \n", progname, infile );
        return moreinput();
    }

    return 1;
}


int demo(){
    if( gargc-- <= 0)
        return 0;
    if ( fin && fin != stdin )
        fclose(fin);
    infile = *gargv++;
    lineno = 1;
     if ( (fin = fopen("demo", "r")) == NULL ) {
        fprintf( stderr, "%s: cant open %s \n", progname, infile );
        return moreinput();
    }

    return 1;
}


void
warning(char *s, char *t)	/* print warning message */
{
	fprintf(stderr, "%s: %s", progname, s);
	if (t)
		fprintf(stderr, " %s", t);
	if (infile)
		fprintf(stderr, " in %s", infile);
	fprintf(stderr, " near line %d\n", lineno);
	while (c != '\n' && c != EOF)
		if((c = getc(fin)) == '\n')	/* flush rest of input line */
			lineno++;
		else if (c == EOF && errno == EINTR) {
			clearerr(stdin);	/* ick! */
			errno = 0;
		}
}

void
defnonly(char *s)	/* warn if illegal definition */
{
	if (!indef)
		execerror(s, "used outside definition");
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

/*GUI*/
GtkWidget *tvCodigo;
GdkPixbuf *imagenTortuga;
GtkTextBuffer *bufferCodigo;
GtkWidget *lblLog;
GtkStyleContext *tvCodigoContext;

FILE *listaComados;
char *comandosbuffer;
GtkAdjustment *ajustevertical;
GtkAdjustment *ajustehorizontal;
GtkAdjustment *pruebaajustes;
GtkWidget *scrollPintar;

static void
cargarGUI ( )
{
    //Window 
    GtkWidget *window;
    GtkWidget *layout;

    //Layouts
    GtkWidget *boxComandos;
    GtkWidget *boxPintar;
    GtkWidget *boxCodigoBoton;
    GtkWidget *scrollCode;
    GtkWidget *scrollComandos;
    GtkWidget *boxBoton;

    //Layout para Logs
    GtkWidget *boxLogs;

    //Layout para los botones
    GtkWidget *boxBotonera;
    GtkWidget *boxIncDec;

    //Frames
    GtkWidget *frameComandos;   
    GtkWidget *framePintar;
    GtkWidget *frameLogs;

    //Labels
    GtkWidget *lblFrameComandos; 
    GtkWidget *tvComandos;

    //botones
    GtkWidget *btnGo;
    GtkWidget *btnIncEscala;
    GtkWidget *btnDecEscala;

    //Area para pintar
    GtkWidget *drawingArea;

    //Para agregar Imagen
    GError *error;
    error = NULL;

    gtk_init(NULL, NULL );
    cargarCSS();

    //Inicializar ventana
    window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title (GTK_WINDOW (window), "LOGO");
    gtk_window_set_default_size (GTK_WINDOW (window), 1000, altowindow);
    gtk_container_set_border_width( GTK_CONTAINER(window), 10 );
    g_signal_connect( window, "delete-event", gtk_main_quit, NULL );
    
    //Cargar imagen en buffer
    imagenTortuga = gdk_pixbuf_new_from_file("pruebat.png", &error);

    //Bufer para texto
    GtkTextBuffer *buffer;
    GtkTextIter start, end;
    
    //textView
    tvComandos = gtk_text_view_new();
    gtk_text_view_set_editable (tvComandos, 0);

    tvCodigo   = gtk_text_view_new();
    gtk_text_view_set_justification( tvCodigo, GTK_JUSTIFY_CENTER);

    //Cargar el buffer con el texto del archivo comandos.txt
    listaComados = fopen("comandos.txt", "r");
    if(!listaComados ) 
        g_print("Error con archivo comandos");
    
    if( fseek(listaComados, 0L, SEEK_END) == 0){
        long tambuff = ftell(listaComados);
        if( tambuff == -1 )
            g_print("Error con archivo comandos");
        comandosbuffer = malloc(sizeof(char) * (tambuff + 1));
            
        if(fseek(listaComados, 0L, SEEK_SET) != 0)
            g_print("Error con archivo comandos");
        
        size_t newLen = fread( comandosbuffer, sizeof(char), tambuff, listaComados);
        if( ferror( listaComados ) != 0 )
            g_print("Error con archivo comandos");
        else     
            comandosbuffer[newLen++] = '\0';
        fclose(listaComados);
    }
    
    //Agregar manejador de eventos a la ventana
    gtk_widget_add_events(window, GDK_KEY_PRESS_MASK);

    //Agregar el buffer al tvComandos
    buffer = gtk_text_view_get_buffer( GTK_TEXT_VIEW(tvComandos));
    gtk_text_buffer_set_text( buffer, comandosbuffer, -1);

    //Agregar buffer al tvCodigo
    bufferCodigo = gtk_text_view_get_buffer( GTK_TEXT_VIEW(tvCodigo));
    gtk_text_buffer_set_text( bufferCodigo, "copo ( )", -1);


    //botones
    btnGo = gtk_button_new_with_label("PINTAR");
    gtk_widget_set_size_request ( btnGo, 70, 50);

    btnIncEscala = gtk_button_new_with_label("+");
    gtk_widget_set_size_request ( btnIncEscala, 35, 50);

    btnDecEscala = gtk_button_new_with_label("-");
    gtk_widget_set_size_request ( btnDecEscala, 35, 50);

    //Labels
    lblFrameComandos = gtk_label_new("Comandos");
    lblLog = gtk_label_new("...");

    
    //Creacion de layouts
    layout = gtk_grid_new();
    boxComandos = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
    boxPintar   = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    scrollCode = gtk_scrolled_window_new (NULL , NULL);
    scrollComandos = gtk_scrolled_window_new (NULL , NULL);
    

    ajustevertical = gtk_adjustment_new (alto/2,0, alto, 20, 1, alto);
    ajustehorizontal = gtk_adjustment_new (ancho/2,0, ancho, 20, 1, alto);

    scrollPintar = gtk_scrolled_window_new (GTK_ADJUSTMENT(ajustehorizontal) , GTK_ADJUSTMENT(ajustevertical));
    pruebaajustes = gtk_scrolled_window_get_vadjustment (scrollPintar);
    
    //Tamaño de scroll
    gtk_widget_set_size_request ( scrollCode, 400, 50);
    gtk_widget_set_size_request ( scrollPintar, ancho, alto);

    gtk_widget_set_vexpand(GTK_WIDGET(scrollPintar), TRUE );

    boxCodigoBoton = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    boxBoton = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);

    boxLogs = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

    //Layout para botones
    boxBotonera = gtk_box_new(GTK_ORIENTATION_HORIZONTAL,   0);

    //Crear frames
    frameComandos = gtk_frame_new("Comandos");
    framePintar   = gtk_frame_new("Pintar");
    gtk_frame_set_shadow_type( framePintar, GTK_SHADOW_OUT );
    frameLogs = gtk_frame_new("Log");

    //Area para pintar
    drawingArea = gtk_drawing_area_new();
    gtk_widget_set_size_request ( drawingArea, ancho, alto);

    //Agregaar elementos al grid
    gtk_grid_attach (GTK_GRID (layout), frameComandos , 0, 0, 10, 10);
    gtk_grid_attach ( GTK_GRID (layout), framePintar,   11, 0 ,20, 10);

    //Agregar clases CSS
    gtk_style_context_add_class( gtk_widget_get_style_context(btnGo), "mybtn");
    gtk_style_context_add_class( gtk_widget_get_style_context(tvCodigo), "txtCodigo");
    gtk_style_context_add_class( gtk_widget_get_style_context(tvComandos), "txtComandos");
    gtk_style_context_add_class( gtk_widget_get_style_context(lblLog), "lblLogs");
    gtk_style_context_add_class( gtk_widget_get_style_context(btnDecEscala), "btnZoom");
    gtk_style_context_add_class( gtk_widget_get_style_context(btnIncEscala), "btnZoom");

    //Cambiar tamaño de frameComandos
    gtk_widget_set_size_request(frameComandos, 300, altowindow);

    //Cambiar tamaño de ventana para pintar
    gtk_widget_set_size_request(framePintar, 500, altowindow);

    //Cambiar tamaño de fram Logs
    gtk_widget_set_size_request(frameLogs, 500, 50);

    //Agregar elementos a boxComandos
    gtk_box_pack_start(boxComandos, scrollComandos, TRUE, TRUE, 0);

    //Agregar elementos a boxPintar
    gtk_box_pack_start(boxPintar, drawingArea, TRUE, TRUE, 0);
    gtk_box_pack_start(boxPintar, boxCodigoBoton, TRUE, TRUE, 0);

    //Agregar elementos a boxCodigoBoton
    gtk_box_pack_start(boxCodigoBoton, scrollCode, TRUE, TRUE, 0);
    gtk_box_pack_start(boxCodigoBoton, boxBoton, TRUE, TRUE, 0);
    gtk_box_pack_start(boxPintar, frameLogs, TRUE, TRUE, 0);

    //Agregar elementos a boxLogs
    gtk_box_pack_start(boxLogs, lblLog, TRUE, TRUE, 0);

    //Agregar elementos aboxbotones
    gtk_box_pack_start(boxBotonera, btnIncEscala, TRUE, TRUE, 0);
    gtk_box_pack_start(boxBotonera, btnDecEscala, TRUE, TRUE, 0);

    //Agregar botonera a boxBoton
    gtk_box_pack_start(boxBoton, btnGo, TRUE, TRUE, 0);
    gtk_box_pack_start(boxBoton, boxBotonera, TRUE, TRUE, 0);

    //agergar tvCodigo a  scroll view
    gtk_container_add (GTK_CONTAINER (scrollCode), tvCodigo);

    //agregar tvComandos a scroll
    gtk_container_add (GTK_CONTAINER (scrollComandos), tvComandos);

    //Agregar layout a window
    gtk_container_add (GTK_CONTAINER (window), layout);

    //Agregar GTKBox a frameComandos
    gtk_container_add( GTK_CONTAINER(frameComandos), boxComandos);

    //Agregar GTKBox a framPintar
    gtk_container_add( GTK_CONTAINER(framePintar), boxPintar);

    //Agregar GTKBox a frame Logs
    gtk_container_add( GTK_CONTAINER(frameLogs), boxLogs);

    //Liga para el area de dibujo
    g_signal_connect (G_OBJECT (drawingArea), "draw",
                    G_CALLBACK (on_draw_event), NULL);

    //Liga para evento del boton
    g_signal_connect (btnGo, "clicked",
		      G_CALLBACK (callback), (gpointer) "cool button");

    //Liga para evento incrementar escala
    g_signal_connect (btnIncEscala, "clicked",
		      G_CALLBACK (incrementarEscala), (gpointer) "inc button");

    //Liga para evento decrementar escala
    g_signal_connect (btnDecEscala, "clicked",
		      G_CALLBACK (decrementarEscala), (gpointer) "dec button");

    //Liga para evento del teclado
    g_signal_connect (G_OBJECT (window), "key_press_event",
              G_CALLBACK (my_keypress_function), NULL);

    //Mostrar la ventana
    gtk_widget_show_all (window);
    gtk_main();
    

}


//Cairo

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Cada que GtkDrawingArea necesita ser repintado se emite una draw signal que se conecta con on_draw_event
static gboolean on_draw_event( GtkWidget *widget, cairo_t *cr, gpointer user_data )
{
    //Se le pasa el contexto a do_drawing
    do_drawing( cr );
    //actualizar drawingArea
    gtk_widget_queue_draw(widget);
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Funcion para pintar
static void do_drawing(cairo_t *cr)
{
    cairo_scale( cr, escalaX, escalaX );
    double xsize  = (1/escalaX)*ancho;
    double ysize  = (1/escalaX)*alto;
    
    //Desplazar el sistema de coordenadas al centro del area de dibujo
    cairo_translate(cr, (xsize/2) + dxWindow , (ysize/2) + dyWindow );    
    //Cargar imagen de la tortuga
    gdk_cairo_set_source_pixbuf(cr, imagenTortuga, -27+fondo->dx,fondo->dy);
    //Rectangulo que almacena la imagen de la tortuga
    cairo_rectangle (cr,
                 -27+fondo->dx,
                 fondo->dy,
                 55,
                 55);
    //Rellenar el rectangulo con la imagen
    cairo_fill(cr);
       
    //Apuntador al primer nodo de la cola
    struct nodo *reco = raiz;
    //Mientras haya más elementos en la cola
    while (reco != NULL)
    {
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
        cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND); 
        //Estableceer el color del pincel
        cairo_set_source_rgba(cr, reco->r, reco->g, reco->b, reco->penup_pendown );
        //Establecer el ancho de la linea
        cairo_set_line_width(cr, 7);
        //Desplazarse al punto inicial de dibujo
        cairo_move_to(cr, reco->x, reco->y);
        //Punto final del dibujo
        cairo_line_to(cr, reco->dx, reco->dy);
        //Siguiente elemento de la cola
        reco = reco->sig;
        //Unir los puntos para formar la linea
        cairo_stroke(cr); 
    }

    //Mostrar mensaje en lblLogs
    gtk_label_set_text(lblLog, msj);

}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Eventos para los botones
static void callback( GtkWidget *widget,
                      gpointer   data )
{
    /*
    * Cuando se ejecuta este evento se cargarn los comandos
    * ingresados en tvComandos en el archivo test.txt
    * para que  sean ejecutados
    */
    g_print("\nexecuting...");
    remove("test.txt");
    
    FILE *file;
    file = fopen("test.txt", "w");
    char *cad = get_text_of_textview( tvCodigo );

    fprintf(file, "%s\n", cad);
    fclose(file);

    while( moreinput() )
        run();

    gargc = 1;
    g_print("\nfinished\n");
    initcode();
    gtk_text_buffer_set_text( bufferCodigo, "", -1);
}


static void decrementarEscala( GtkWidget *widget, gpointer data )
{
    if(  !(escalaX == 0.4) ){
        escalaX = escalaX - 0.1;
    }
}


static void incrementarEscala( GtkWidget *widget, gpointer data )
{
    if(  !(escalaX >= 2) ){
        escalaX = escalaX + 0.1;
    }
}

//Evento para el desplazamiento por medio de ctrl + direccion
static gboolean my_keypress_function (GtkWidget *widget, GdkEventKey *event, gpointer data) {
    switch( event->keyval ){
        case GDK_KEY_Up:
            if( event->state & GDK_CONTROL_MASK ){
                dyWindow = dyWindow - 50;
            }
        break;
        case GDK_KEY_Down:
            if( event->state & GDK_CONTROL_MASK ){
                dyWindow = dyWindow + 50;
            }
        break;
        case GDK_KEY_Left:
            if( event->state & GDK_CONTROL_MASK ){
                dxWindow = dxWindow - 50;
            }
        break;
        case GDK_KEY_Right:
            if( event->state & GDK_CONTROL_MASK ){
                dxWindow = dxWindow + 50;
            }
        break;

        default:
            return FALSE;
    }
   
    return FALSE;
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//insertar un nodo en la lista
void insertar(float x, float y, float dx, float dy, char penup_pendown, float r, float g, float b )
{
    struct nodo *nuevo;
    nuevo=malloc(sizeof(struct nodo));
    nuevo->x  = x;
    nuevo->y  = y;
    nuevo->dx = x + dx;
    nuevo->dy = y + dy;
    nuevo->r = r;
    nuevo->g = g;
    nuevo->b = b;
    nuevo->penup_pendown = penup_pendown;
    nuevo->sig=NULL;
    if (vacia())
    {
        raiz = nuevo;
        fondo = nuevo;
        inicioPuntos = nuevo;
    }
    else
    {
        fondo->sig = nuevo;
        fondo = nuevo;
    }

    counter++;
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Obtener texto de un textView
char *get_text_of_textview(GtkWidget *text_view) {
    GtkTextIter start, end;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer((GtkTextView *)text_view);
    gchar *text;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    text = gtk_text_buffer_get_text(buffer, &start, &end, FALSE);
    return text;
}

//Metodo para saber si la cola esta vacia
int vacia()
{
    if (raiz == NULL)
        return 1;
    else
        return 0;
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Metodo para eliminar los elementos guardados en la cola
void eliminar()
{

    struct nodo *reco = raiz;
    struct nodo *bor;
    while (reco != NULL)
    {
        bor = reco;
        reco = reco->sig;
        free(bor);
    }
    counter = 0;
    raiz   = NULL;
    fondo  = NULL;
    
    /*
    * Ya que no hay elementos se regresa el angulo a la 
    * posicion inicial
    */
    angulo = 90;
    //Se inserta un punto el cual sera el punto de partida
    insertar(0,0,0,0,1, 70/255, 130/255, 180/255);
    raiz->penup_pendown = 0;
}

/* 
*LOGO
*@autor : Pacheco Castillo Isaias - 3CM7 
*/

//Metodo para cargar estilos CSS 
static void cargarCSS(){
    GtkCssProvider *provider;
    GdkDisplay *display;
    GdkScreen *screen;

    const gchar *css_style_file = "my.css";
    GFile *css_fp               = g_file_new_for_path( css_style_file );
    GError *error = NULL;

    provider = gtk_css_provider_new();
    display  = gdk_display_get_default();
    screen   = gdk_display_get_default_screen( display );

    gtk_style_context_add_provider_for_screen( screen, GTK_STYLE_PROVIDER(provider), 800);
    gtk_css_provider_load_from_file( provider, css_fp, &error );
    if (error)
{
    // Muestra error si no se cargo el archivo
    g_warning ("%s", error->message);
    g_clear_error (&error);
}
    
    g_object_unref( provider );
}