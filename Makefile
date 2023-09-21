# Makefile for ITA TOOLKIT #5 rmdir

AS	= \usr\pds\HAS.X -l -i $(INCLUDE)
LK	= \usr\pds\hlk.x -x
CV      = -\bin\CV.X -r
INSTALL = copy
BACKUP  = A:\bin\COPYALL.X -t
CP      = copy
RM      = -\usr\local\bin\rm -f

INCLUDE = $(HOME)/fish/include

DESTDIR   = A:\usr\local\bin
BACKUPDIR = B:\rmdir\1.0

EXTLIB = $(HOME)/fish/lib/ita.l

###

PROGRAM = rmdir.x

###

.PHONY: all clean clobber install backup

.TERMINAL: *.h *.s

%.r : %.x	; $(CV) $<
%.x : %.o	; $(LK) $< $(EXTLIB)
%.o : %.s	; $(AS) $<

###

all:: $(PROGRAM)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAM) : $(INCLUDE)/doscall.h $(INCLUDE)/chrcode.h $(EXTLIB)

install::
	$(INSTALL) $(PROGRAM) $(DESTDIR)

backup::
	$(BACKUP) *.* $(BACKUPDIR)

clean::
	$(RM) $(PROGRAM)

###
