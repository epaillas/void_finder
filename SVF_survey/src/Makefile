# Compiler choice

FC = gfortran
MPIFC = mpif90

MLIBS = -lm

#################

EXES_3D = grow_spheres.exe recentring.exe overlapping.exe vg_ccf_r_mu.exe vg_ccf_sigma_pi.exe
EXES_2D = 
EXES = $(EXES_3D) $(EXES_2D)

all: $(EXES)

vg_ccf_r_mu.exe: vg_ccf_r_mu.o
	$(FC) vg_ccf_r_mu.o -o vg_ccf_r_mu.exe

vg_ccf_sigma_pi.exe: vg_ccf_sigma_pi.o
	$(FC) vg_ccf_sigma_pi.o -o vg_ccf_sigma_pi.exe

grow_spheres.exe: grow_spheres.o
	$(MPIFC) grow_spheres.o -o grow_spheres.exe $(MLIBS)

recentring.exe: recentring.o
	$(MPIFC) recentring.o -o recentring.exe $(MLIBS)

overlapping.exe: overlapping.o
	$(MPIFC) overlapping.o -o overlapping.exe $(MLIBS)


vg_ccf_r_mu.o: vg_ccf_r_mu.f90
	$(FC) -c vg_ccf_r_mu.f90

vg_ccf_sigma_pi.o: vg_ccf_sigma_pi.f90
	$(FC) -c vg_ccf_sigma_pi.f90

grow_spheres.o: grow_spheres.f90
	$(MPIFC) -c grow_spheres.f90

recentring.o: recentring.f90
	$(MPIFC) -c recentring.f90

overlapping.o: overlapping.f90
	$(MPIFC) -c overlapping.f90



r8lib.o: r8lib.f90
	$(FC) -c r8lib.f90

install: $(EXES)
	mv $(EXES) ../bin

clean:
	rm -f $(EXES) *.o *~ *.mod
