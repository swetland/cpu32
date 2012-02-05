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
	unsigned n;
	char dis[128];
	FILE *fp = fopen(fn, "w");
	if (!fp) die("cannot write to '%s'", fn);
	for (n = 0; n < PC; n++) {
		disassemble(dis, n, rom[n]);
		fprintf(fp, "%08x  // %08x: %s\n", rom[n], n, dis);
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
	tSEQ, tSLT, tSGT, tREV, tBIS, tBIC, tMOV, tMHI,
	tB, tBL, tBZ, tBNZ, tBLZ, tBLNZ, tLW, tSW,
	tR0, tR1, tR2, tR3, tR4, tR5, tR6, tR7,
	rR8, tR9, tR10, tR11, tR12, tR13, tR14, tR15,
	tSP, tLR,
	tNOP, 
	tEQU,
	NUMTOKENS,
};

char *tnames[] = {
	"<EOL>",
	",", ":", "[", "]", ".",
	"<STRING>",
	"<NUMBER>",
	"ORR", "AND", "ADD", "SUB", "SHL", "SHR", "XOR", "TBS",
	"SEQ", "SLT", "SGT", "REV", "BIS", "BIC", "MOV", "MHI",
	"B",   "BL",  "BZ",  "BNZ", "BLZ", "BLNZ", "LW", "SW",
	"R0",  "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7",
	"R8",  "R9",  "R10", "R11", "R12", "R13", "R14", "R15",
	"SP",  "LR",
	"NOP",
	"EQU",
};

#define FIRST_ALU_OP	tORR
#define LAST_ALU_OP	tMHI
#define FIRST_REGISTER	tR0
#define LAST_REGISTER	tR15

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

void disassemble(char *buf, unsigned pc, unsigned instr) {
	unsigned op = instr >> 28;
	unsigned fn = (instr >> 24) & 0xF;
	unsigned opfn = (instr >> 24) & 0xFF;
	unsigned a = (instr >> 20) & 0xF;
	unsigned b = (instr >> 16) & 0xF;
	unsigned d = (instr >> 12) & 0xF;
	unsigned i16 = instr & 0xFFFF;
	short s16 = i16;

		/* check for special forms */
	if (instr == 0) {
		sprintf(buf, "NOP");
		return;
	}

	switch (opfn) {
	case 0x0B:
	case 0x1B:
		sprintf(buf, "REV  %s, %s", REG(d), REG(a));
		break;
	case 0x0E:
		sprintf(buf, "MOV  %s, %s", REG(d), REG(b));
		break;
	case 0x1E:
		sprintf(buf, "MOV  %s, #%d", REG(d), i16);
		break;
	case 0x0F:
		sprintf(buf, "MHI  %s, %s", REG(d), REG(b));
		break;
	case 0x1F:
		sprintf(buf, "MHI  %s, #%d", REG(d), i16);
		break;
	case 0x20:
		sprintf(buf, "LW   %s, [%s, #%d]", REG(b), REG(a), i16);
		break;
	case 0x30:
		sprintf(buf, "SW   %s, [%s, #%d]", REG(b), REG(a), i16);
		break; 
	case 0x41:
		sprintf(buf, "BZ   %s, 0x%08x", REG(a), (pc + s16));
		break;
	case 0x42:
		sprintf(buf, "BNZ  %s, 0x%08x", REG(a), (pc + s16));
		break;
	case 0x43:
		sprintf(buf, "B    0x%08x", (pc + s16));
		break;
	case 0x49:
		sprintf(buf, "BLZ  %s, 0x%08x", REG(a), (pc + s16));
		break;
	case 0x4A:
		sprintf(buf, "BLNZ %s, 0x%08x", REG(a), (pc + s16));
		break;
	case 0x4B:
		sprintf(buf, "BL   0x%08x", (pc + s16));
		break;
	default:
		if (op == 0) {
			sprintf(buf, "%-5s%s, %s, %s",
				tnames[FIRST_ALU_OP + fn], REG(d), REG(a), REG(b));
		} else if (op == 1) {
			sprintf(buf, "%-5s%s, %s, #%d",
				tnames[FIRST_ALU_OP + fn], REG(b), REG(a), i16);
			return;
		} else {
			sprintf(buf, "UND 0x%04x", opfn);
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
		emit(0x1E000000 | TO_B(to_register(tok[1])) | TO_I16(num[3]));
		if (num[3] & 0xFFFF0000)
			emit(0x1F000000 | TO_B(to_register(tok[1])) | (TO_I16(num[3] >> 16)));
		return;
	case tMHI:
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		expect(tNUMBER,tok[3]);
		emit(0x1F000000 | TO_B(to_register(tok[1])) | TO_I16(num[3]));
		return;
	case tB:
	case tBL:
		if (tok[0] == tB) {
			instr = 0x43000000;
		} else {
			instr = 0x4B000000;
		}
		if (tok[1] == tSTRING) {
			emit(instr);
			uselabel(str[1], PC - 1, 16);
		} else if ((tok[1] == tNUMBER) || (tok[1] == tDOT)) {
			if (!is_signed_16(num[1])) die("branch target out of range");
			emit(instr | TO_I16(num[1]));
		} else {
			die("expected branch target, got %s", tnames[tok[1]]);
		}
		return;
	case tBNZ:
	case tBZ:
	case tBLNZ:
	case tBLZ:
		switch (tok[0]) {
		case tBZ:   instr = 0x41000000; break;
		case tBNZ:  instr = 0x42000000; break;
		case tBLZ:  instr = 0x49000000; break;
		case tBLNZ: instr = 0x4A000000; break;
		}
		expect_register(tok[1]);
		expect(tCOMMA,tok[2]);
		instr |= TO_A(to_register(tok[1]));
		if (tok[3] == tSTRING) {
			emit(instr);
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
			instr = 0x20000000;
		} else {
			instr = 0x30000000;
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
