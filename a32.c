// Copyright 2009-2012, Brian Swetland.  Use at your own risk.

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <strings.h>
#include <string.h>

static unsigned linenumber = 0;
static char linestring[256];
static char *filename;

FILE *ofp = 0;

void die(const char *fmt, ...) {
	va_list ap;
	fprintf(stderr,"%s:%d: ", filename, linenumber);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fprintf(stderr,"\n");
	if (linestring[0])
		fprintf(stderr,"%s:%d: >> %s <<\n", filename, linenumber, linestring);
	exit(1);
}

int is_signed_16(unsigned n) {
	if (n < 0xFFFF)
		return 1;
	if ((n & 0xFFFF0000) == 0xFFFF0000)
		return 1;
	return 0;
}

unsigned rom[65535];
unsigned PC = 0;

struct fixup {
	struct fixup *next;
	unsigned pc;
	unsigned type;  // 16, 24
};

struct label {
	struct label *next;
	struct fixup *fixups;
	const char *name;
	unsigned pc;
	unsigned defined;
};

struct label *labels;
struct fixup *fixups;

void fixup_branch(const char *name, int addr, int btarget, int type) {
	unsigned n;

	n = btarget - addr;

	if (!is_signed_16(n)) {
		die("label '%s' at %08x is out of range of %08x\n",
			name, btarget, addr);
	}
	rom[addr] = (rom[addr] & 0xFFFF0000) | (n & 0xFFFF);
}

void setlabel(const char *name, unsigned pc) {
	struct label *l;
	struct fixup *f;

	for (l = labels; l; l = l->next) {
		if (!strcasecmp(l->name, name)) {
			if (l->defined) die("cannot redefine '%s'", name);
			l->pc = pc;
			l->defined = 1;
			for (f = l->fixups; f; f = f->next) {
				fixup_branch(name, f->pc, l->pc, f->type);
			}
			return;
		}
	}
	l = malloc(sizeof(*l));
	l->name = strdup(name);
	l->pc = pc;
	l->fixups = 0;
	l->defined = 1;
	l->next = labels;
	labels = l;
}

const char *getlabel(unsigned pc) {
	struct label *l;
	for (l = labels; l; l = l->next)
		if (l->pc == pc)
			return l->name;
	return 0;
}

void uselabel(const char *name, unsigned pc, unsigned type) {
	struct label *l;
	struct fixup *f;

	for (l = labels; l; l = l->next) {
		if (!strcasecmp(l->name, name)) {
			if (l->defined) {
				fixup_branch(name, pc, l->pc, type);
				return;
			} else {
				goto add_fixup;
			}
		}
	}
	l = malloc(sizeof(*l));
	l->name = strdup(name);
	l->pc = 0;
	l->fixups = 0;
	l->defined = 0;
	l->next = labels;
	labels = l;
add_fixup:
	f = malloc(sizeof(*f));
	f->pc = pc;
	f->type = type;
	f->next = l->fixups;
	l->fixups = f;
}

void checklabels(void) {
	struct label *l;
	for (l = labels; l; l = l->next) {
		if (!l->defined) {
			die("undefined label '%s'", l->name);
		}
	}
}
	
void disassemble(char *buf, unsigned pc, unsigned instr);
	
void emit(unsigned instr) {
	rom[PC++] = instr;
}

void save(const char *fn) {
	const char *name;
	unsigned n;
	char dis[128];
	FILE *fp = fopen(fn, "w");
	if (!fp) die("cannot write to '%s'", fn);
	for (n = 0; n < PC; n++) {
		disassemble(dis, n * 4, rom[n]);
		name = getlabel(n);
		if (name) {
			fprintf(fp, "%08x  // %04x: %-25s <- %s\n", rom[n], n*4, dis, name);
		} else {
			fprintf(fp, "%08x  // %04x: %s\n", rom[n], n*4, dis);
		}
	}
	fclose(fp);
}

#define MAXTOKEN 32

enum tokens {
	tEOL,
	tCOMMA, tCOLON, tOBRACK, tCBRACK, tDOT,
	tSTRING,
	tNUMBER,
	tORR, tAND, tADD, tSUB, tSHL, tSHR, tXOR, tTBS,
	tBIS, tBIC, tSLT, tSGT, tMLO, tMHI, tASR, tMUL,
	tB, tBL, tBZ, tBNZ, tBLZ, tBLNZ, tLW, tSW,
	tR0, tR1, tR2, tR3, tR4, tR5, tR6, tR7,
	rR8, tR9, tR10, tR11, tR12, tSP, tLR, tZR,
	tNOP, tSNE, tNOT, tMOV,
	tEQU, tWORD, tASCII, tASCIIZ,
	NUMTOKENS,
};

char *tnames[] = {
	"<EOL>",
	",", ":", "[", "]", ".",
	"<STRING>",
	"<NUMBER>",
	"ORR", "AND", "ADD", "SUB", "SHL", "SHR", "XOR", "TBS",
	"BIS", "BIC", "SLT", "SGT", "MLO", "MHI", "ASR", "MUL",
	"B",   "BL",  "BZ",  "BNZ", "BLZ", "BLNZ", "LW", "SW",
	"R0",  "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7",
	"R8",  "R9",  "R10", "R11", "R12", "SP", "LR", "ZR",
	"NOP", "SNE", "NOT", "MOV",
	"EQU", "WORD", "STRING", "ASCIIZ"
};

#define FIRST_ALU_OP	tORR
#define LAST_ALU_OP	tMUL
#define FIRST_REGISTER	tR0
#define LAST_REGISTER	tZR

int is_register(unsigned tok) {
	return ((tok >= FIRST_REGISTER) && (tok <= LAST_REGISTER));
}

int is_alu_op(int token) {
	return ((token >= FIRST_ALU_OP) && (token <= LAST_ALU_OP));
}

unsigned to_register(unsigned tok) {
	if (!is_register(tok)) die("not a register (%s)", tnames[tok]);
	return tok - FIRST_REGISTER;
}

int is_stopchar(unsigned x) {
	switch (x) {
	case 0:
	case ' ':
	case '\t':
	case '\r':
	case '\n':
	case ',':
	case ':':
	case '[':
	case ']':
	case '.':
	case '"':
		return 1;
	default:
		return 0;
	}
}	
int is_eoschar(unsigned x) {
	switch (x) {
	case 0:
	case '\t':
	case '\r':
	case '"':
		return 1;
	default:
		return 0;
	}
}

int tokenize(char *line, unsigned *tok, unsigned *num, char **str) {
	char *s;
	int count = 0;
	unsigned x, n, neg;
	linenumber++;

	for (;;) {
		x = *line;
	again:
		if (count == 31) die("line too complex");

		switch (x) {
		case 0:
			goto alldone;
		case ' ':
		case '\t':
		case '\r':
		case '\n':			
			line++;
			continue;
		case '/':
			if (line[1] == '/')
				goto alldone;
			
		case ',':
			str[count] = ",";
			num[count] = 0;
			tok[count++] = tCOMMA;
			line++;
			continue;
		case ':':
			str[count] = ":";
			num[count] = 0;
			tok[count++] = tCOLON;
			line++;
			continue;
		case '[':
			str[count] = "[";
			num[count] = 0;
			tok[count++] = tOBRACK;
			line++;
			continue;
		case ']':
			str[count] = "]";
			num[count] = 0;
			tok[count++] = tCBRACK;
			line++;
			continue;
		case '.':
			str[count] = ".";
			num[count] = 0;
			tok[count++] = tDOT;
			line++;
			continue;
		case '"':
			str[count] = ++line;
			num[count] = 0;
			tok[count++] = tSTRING;
			while (!is_eoschar(*line)) line++;
			if (*line != '"')
				die("unterminated string");
			*line++ = 0;
			continue;
		}

		s = line++;
		while (!is_stopchar(*line)) line++;

			/* save the stopchar */
		x = *line;
		*line = 0;

		neg = (s[0] == '-');
		if (neg && isdigit(s[1])) s++;

		str[count] = s;
		if (isdigit(s[0])) {
			num[count] = strtoul(s, 0, 0);
			if(neg) num[count] = -num[count];
			tok[count++] = tNUMBER;
			goto again;
		}
		if (isalpha(s[0])) {
			num[count] = 0;
			for (n = tNUMBER + 1; n < NUMTOKENS; n++) {
				if (!strcasecmp(s, tnames[n])) {
					str[count] = tnames[n];
					tok[count++] = n;
					goto again;
				}
			}

			while (*s) {
				if (!isalnum(*s) && (*s != '_'))
					die("invalid character '%c' in identifier", *s);
				s++;
			}
			tok[count++] = tSTRING;
			goto again;
		}
		die("invalid character '%c'", s[0]);
	}

alldone:			
	str[count] = "";
	num[count] = 0;
	tok[count++] = tEOL;
	return count;
}


void expect(unsigned expected, unsigned got) {
	if (expected != got)
		die("expected %s, got %s", tnames[expected], tnames[got]);
}

void expect_register(unsigned got) {
	if (!is_register(got))
		die("expected register, got %s", tnames[got]);
}

#define REG(n) (tnames[FIRST_REGISTER + (n)])

int match(unsigned n, unsigned mask, unsigned value) {
	return (n & mask) == value;
}

char *append(char *buf, char *s)
{
	while (*s)
		*buf++ = *s++;
	return buf;
}
char *append_u32(char *buf, unsigned n) {
	sprintf(buf,"%08x",n);
	return buf + strlen(buf);
}
char *append_u16(char *buf, unsigned n) {
	sprintf(buf,"%04x",n&0xFFFF);
	return buf + strlen(buf);
}
char *append_s16(char *buf, short n) {
	sprintf(buf,"%d",n);
	return buf + strlen(buf);
}

void printinst(char *buf, unsigned pc, unsigned instr, const char *fmt) {
	unsigned fn = (instr >> 24) & 0xF;
	unsigned a = (instr >> 20) & 0xF;
	unsigned b = (instr >> 16) & 0xF;
	unsigned d = (instr >> 12) & 0xF;
	unsigned i16 = instr & 0xFFFF;
	int s16 = ((short) i16) * 4;

	while (*fmt) {
		if (*fmt != '@') {
			*buf++ = *fmt++;
			continue;
		}
		switch (*++fmt) {
		case 'A':
			buf = append(buf,REG(a));
			break;
		case 'B':
			buf = append(buf,REG(b));
			break;
		case 'D':
			buf = append(buf,REG(d));
			break;
		case 'F': /* alu function */
			buf = append(buf,tnames[FIRST_ALU_OP + fn]);
			break;
		case 'u':
			buf = append_u16(buf,i16);
			break;
		case 's':
			buf = append_s16(buf,(short)i16);
			break;
		case 'r':
			buf = append(buf,"0x");
			buf = append_u32(buf,(pc + s16));
			break;
		case 0:
			goto done;
		}
		fmt++;
	}
done:
	*buf = 0;
}

struct {
	unsigned mask;
	unsigned value;
	const char *fmt;
} decode[] = {
	{ 0xFFFFFFFF, 0x00000000, "NOP", },
	{ 0xFFFFFFFF, 0xFFFFFFFF, "HALT", },
	{ 0xFFF00000, 0x10F00000, "MOV @B, #@s", }, // ORR Rd, Rz, #I 
	{ 0xFFF00000, 0x1CF00000, "MLO @B, #0x@u", }, // MLO Rd, Rz, #I 
	{ 0xFFF00000, 0x1DF00000, "MOV @B, #0x@u0000", }, // MHI Rd, Rz, #I
	{ 0xFF000000, 0x1C000000, "MLO @B, @A, #0x@u", }, // MLO Rd, Ra, #I
	{ 0xF0000000, 0x00000000, "@F @D, @A, @B", },
	{ 0xF0000000, 0x10000000, "@F @B, @A, @s", },
	{ 0xFF00FFFF, 0x22000000, "LW @B, [@A]", },
	{ 0xFF000000, 0x22000000, "LW @B, [@A, #@s]", },
	{ 0xFF00FFFF, 0x32000000, "SW @B, [@A]", },
	{ 0xFF000000, 0x32000000, "SW @B, [@A, #@s]", },
	{ 0xFFFF0000, 0x40FF0000, "B @r", },
	{ 0xFFFF0000, 0x40FE0000, "BL @r", },
	{ 0xFF0F0000, 0x400F0000, "BZ @A, @r", },
	{ 0xFF0F0000, 0x400E0000, "BLZ @A, @r", },
	{ 0xFFF0F000, 0x44F0F000, "B @B", },
	{ 0xFFF0F000, 0x44F0E000, "BL @B", },
	{ 0xFF00F000, 0x4400F000, "BZ @A, @B", },
	{ 0xFF00F000, 0x4400E000, "BLZ @A, @B", },
	{ 0xFF0F0000, 0x480F0000, "BNZ @A, @r", },
	{ 0xFF0F0000, 0x480E0000, "BLNZ @A, @r", },
	{ 0xFF00F000, 0x4800F000, "BNZ @A, @B", },
	{ 0xFF00F000, 0x4800E000, "BLNZ @A, @B", },
	{ 0x00000000, 0x00000000, "UNDEFINED", },
};

void disassemble(char *buf, unsigned pc, unsigned instr) {
	int n = 0;
	for (n = 0 ;; n++) {
		if ((instr & decode[n].mask) == decode[n].value) {
			printinst(buf, pc, instr, decode[n].fmt);
			return;
		}
	}
}

#define TO_A(n) (((n) & 0xF) << 20)
#define TO_B(n) (((n) & 0xF) << 16)
#define TO_D(n) (((n) & 0xF) << 12)
#define TO_I16(n) ((n) & 0xFFFF)

void assemble_line(int n, unsigned *tok, unsigned *num, char **str) {
	unsigned instr = 0;
	unsigned tmp;
	
	if (tok[0] == tSTRING) {
		if (tok[1] == tCOLON) {
			setlabel(str[0],PC);
			tok+=2;
			num+=2;
			str+=2;
			n-=2;
		} else {
			die("unexpected identifier '%s'", str[0]);
		}
	}

	switch(tok[0]) {
	case tEOL:
			/* blank lines are fine */
		return;
	case tNOP:
		emit(0x00000000);
		return;
	case tMOV:
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		expect(tNUMBER,tok[3]);
		if (num[3] == 0xFFFF) {
			/* special case, need to use MLO */
			emit(0x1CF0FFFF | TO_B(to_register(tok[1])));
			return;
		}
		tmp = num[3] & 0xFFFF8000;
		if ((tmp == 0) || (tmp == 0xFFFF8000)) {
			/* otherwise, sign extending MOV instruction will work */
			emit(0x10F00000 | TO_B(to_register(tok[1])) | TO_I16(num[3]));
			return;
		}
		/* MHI Rd, Rz, #I  instruction to set the high bits */
		emit(0x1DF00000 | TO_B(to_register(tok[1])) | (TO_I16(num[3] >> 16)));
		if (num[3] & 0xFFFF) {
			/* MLO Rd, Rd, #I - in the low bits if present */
			emit(0x1C000000 | TO_A(to_register(tok[1])) | TO_B(to_register(tok[1])) | TO_I16(num[3]));
		}
		return;
	case tMHI:
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		expect(tNUMBER,tok[3]);
		emit(0x1D000000 | TO_B(to_register(tok[1])) | TO_I16(num[3]));
		return;
	case tB:
	case tBL:
		if (tok[0] == tB) {
			tmp = 15;
		} else {
			tmp = 14;
		}
		if (is_register(tok[1])) {
			emit(0x44F00000 | TO_D(tmp) | TO_B(to_register(tok[1])));
		} else if (tok[1] == tSTRING) {
			emit(0x40F00000 | TO_B(tmp));
			uselabel(str[1], PC - 1, 16);
		} else if ((tok[1] == tNUMBER) || (tok[1] == tDOT)) {
			if (!is_signed_16(num[1])) die("branch target out of range");
			emit(0x40F00000 | TO_B(tmp) | TO_I16(num[1]));
		} else {
			die("expected branch target, got %s", tnames[tok[1]]);
		}
		return;
	case tBNZ:
	case tBZ:
	case tBLNZ:
	case tBLZ:
		switch (tok[0]) {
		case tBZ:   instr = 0x40000000; tmp = 15; break;
		case tBNZ:  instr = 0x48000000; tmp = 15; break;
		case tBLZ:  instr = 0x40000000; tmp = 14; break;
		case tBLNZ: instr = 0x48000000; tmp = 14; break;
		}
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		instr |= TO_A(to_register(tok[1]));
		if (is_register(tok[3])) {
			emit(instr | 0x04000000 | TO_D(tmp) | TO_B(to_register(tok[3])));
		} else if (tok[3] == tSTRING) {
			emit(instr | TO_B(tmp));
			uselabel(str[3], PC - 1, 16);
		} else if ((tok[3] == tNUMBER) || (tok[3] == tDOT)) {
			if (!is_signed_16(num[3])) die("branch target out of range");
			emit(instr | TO_I16(num[3]));
		} else {
			die("expected branch target, got %s", tnames[tok[1]]);
		}
		return;
	case tLW:
	case tSW:
		if (tok[0] == tLW) {
			instr = 0x22000000;
		} else {
			instr = 0x32000000;
		}
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		expect(tOBRACK,tok[3]);
		expect_register(tok[4]);
		if (tok[5] == tCOMMA) {
			expect(tNUMBER, tok[6]);
			expect(tCBRACK, tok[7]);
			tmp = num[6];
		} else {
			expect(tCBRACK, tok[5]);
			tmp = 0;
		}
		if (!is_signed_16(tmp)) die("index too large");
		instr |= TO_B(to_register(tok[1])) | TO_A(to_register(tok[4]) | TO_I16(tmp));
		emit(instr);
		return;
	case tWORD:
		tmp = 1;
		for (;;) {
			expect(tNUMBER, tok[tmp]);
			emit(num[tmp++]);
			if (tok[tmp] != tCOMMA)
				break;
			tmp++;
		}
		return;
	case tASCII:
	case tASCIIZ: {
		unsigned n = 0, c = 0; 
		const unsigned char *s = (void*) str[1];
		expect(tSTRING, tok[1]);
		while (*s) {
			n |= ((*s) << (c++ * 8));
			if (c == 4) {
				emit(n);
				n = 0;
				c = 0;
			}
			s++;
		}
		emit(n);
		return;
	}
	}
	if (is_alu_op(tok[0])) {
		expect_register(tok[1]);
		expect(tok[2],tCOMMA);
		expect_register(tok[3]);
		expect(tok[4],tCOMMA);

		instr = ((tok[0] - FIRST_ALU_OP) << 24) | TO_A(tok[3]);

		if (is_register(tok[5])) {
			emit(instr | TO_B(to_register(tok[5])) | TO_D(to_register(tok[1])));
		} else if (tok[5] == tNUMBER) {
			if (num[5] > 65535) die("immediate too large");
			emit(instr | 0x10000000 | TO_B(to_register(tok[1])) | TO_I16(num[5]));
		} else {
			die("expected register or #, got %s", tnames[tok[5]]);
		}
		return;
	}

	die("HUH");
		
}

void assemble(const char *fn)
{
	FILE *fp;
	char line[256];
	int n;

	unsigned tok[MAXTOKEN];
	unsigned num[MAXTOKEN];
	char *str[MAXTOKEN];
	char *s;

	fp = fopen(fn, "r");
	if (!fp) die("cannot open '%s'", fn);

	while (fgets(line, sizeof(line)-1, fp)) {
		strcpy(linestring, line);
		s = linestring;
		while (*s) {
			if ((*s == '\r') || (*s == '\n')) *s = 0;
			else s++;
		}
		n = tokenize(line, tok, num, str);
#if DEBUG
		{
			int i
			printf("%04d: (%02d)  ", linenumber, n);
			for (i = 0; i < n; i++)
				printf("%s ", tnames[tok[i]]);
			printf("\n");
		}
#endif
		assemble_line(n, tok, num, str);
	}
}


int main(int argc, char **argv)
{
	const char *outname = "out.hex";
	filename = argv[1];

	if (argc < 2)
		die("no file specified");
	if (argc == 3)
		outname = argv[2];

	assemble(filename);
	linestring[0] = 0;
	checklabels();
	save(outname);

	return 0;
}
