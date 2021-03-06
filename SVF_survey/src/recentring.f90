module procedures
  implicit none
contains

  subroutine linked_list(ngrid, rgrid, gridmin, gridmax, ll, lirst, pos)
    implicit none
    integer :: i, ng, ipx, ipy, ipz
    integer, intent(in) :: ngrid
    real*8, intent(in) :: gridmin, gridmax, rgrid
    real*8, dimension(:,:), intent(in) :: pos
    integer, dimension(:,:,:), intent(out) :: lirst
    integer, dimension(:), intent(out) :: ll

    ng = size(pos, dim=2)
    lirst = 0
    ll = 0
    do i = 1, ng
      ipx = int((pos(1, i) - gridmin) / rgrid + 1.)
      ipy = int((pos(2, i) - gridmin) / rgrid + 1.)
      ipz = int((pos(3, i) - gridmin) / rgrid + 1.)
      if(ipx.gt.0.and.ipx.le.ngrid.and.ipy.gt.0.and.ipy.le.ngrid.and.&
      ipz.gt.0.and.ipz.le.ngrid) lirst(ipx, ipy, ipz) = i
    end do

    do i = 1, ng
      ipx = int((pos(1, i) - gridmin) / rgrid + 1.)
      ipy = int((pos(2, i) - gridmin) / rgrid + 1.)
      ipz = int((pos(3, i) - gridmin) / rgrid + 1.)

      if (ipx.gt.0.and.ipx.le.ngrid.and.ipy.gt.0.and.ipy.le.ngrid.and.ipz&
      &.gt.0.and.ipz.le.ngrid) then
        ll(lirst(ipx, ipy, ipz)) = i
        lirst(ipx, ipy, ipz) = i
      endif
    end do

  end subroutine linked_list

  character(len=20) function str(k)
    implicit none
    integer, intent(in) :: k
    write(str, *) k
    str = adjustl(str)
  end function str

end module procedures

program recentring
  use mpi
  use procedures
  implicit none

  real*8 :: delta, gridmin, gridmax, rgrid, nden
  real*8 :: px, py, pz, disx, disy, disz, dis
  real*8 :: pxr, pyr, pzr, rvoidr
  real*8 :: rvoid, rwidth, rvoidmax
  real*8 :: rnd, rnd_phi, rnd_theta, rnd_rvoid
  real*8 :: rnd_px, rnd_py, rnd_pz, rnd_ngv, rnd_nden
  real*8 :: pi = 4.*atan(1.)

  integer :: ng, nr, nv, nc, rind, ngv
  integer :: id, ierr, process_num, iargc, filenumber
  integer :: i, j, k, ii, ix, iy, iz
  integer :: ipx, ipy, ipz, ndif, stuck
  integer, parameter :: ngrid = 100, nrbin = 1000, nrc = 128

  integer, dimension(ngrid, ngrid, ngrid) :: lirst_data, lirst_rand
  integer, dimension(:), allocatable :: ll_data, ll_rand

  real*8, dimension(:,:), allocatable  :: pos_data, pos_rand
  real*8, dimension(nrbin) :: rbin_data, rbin_rand, crbin_data, crbin_rand

  character(len=500) :: input_tracers, input_randoms, input_centres, output_voids
  character(len=10) :: rvoidmax_char, delta_char, gridmin_char, gridmax_char
  character(len=1)  :: creturn = achar(13)

  call MPI_Init(ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, process_num, ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, id, ierr)

  if (iargc() .ne. 8) then
    if (id == 0) write(*,*) 'Some arguments are missing.'
    if (id == 0) write(*,*) '1) input_data'
    if (id == 0) write(*,*) '2) input_randoms'
    if (id == 0) write(*,*) '3) input_centres'
    if (id == 0) write(*,*) '4) output_voids'
    if (id == 0) write(*,*) '5) density_threshold'
    if (id == 0) write(*,*) '6) rvoidmax'
    if (id == 0) write(*,*) '7) gridmin'
    if (id == 0) write(*,*) '8) gridmax'
    if (id == 0) write(*,*) ''
    call MPI_Finalize(ierr)
    stop
  end if

  call getarg(1, input_tracers)
  call getarg(2, input_randoms)
  call getarg(3, input_centres)
  call getarg(4, output_voids)
  call getarg(5, delta_char)
  call getarg(6, rvoidmax_char)
  call getarg(7, gridmin_char)
  call getarg(8, gridmax_char)

  read(delta_char, *) delta
  read(gridmin_char, *) gridmin
  read(gridmax_char, *) gridmax
  read(rvoidmax_char, *) rvoidmax

  if (id == 0) write(*,*) '-----------------------'
  if (id == 0) write(*,*) 'Running recentring.exe'
  if (id == 0) write(*,*) 'Input parameters:'
  if (id == 0) write(*,*) ''
  if (id == 0) write(*, *) 'mpi_processes: ', process_num
  if (id == 0) write(*, *) 'input_tracers: ', trim(input_tracers)
  if (id == 0) write(*, *) 'input_randoms: ', trim(input_randoms)
  if (id == 0) write(*, *) 'input_centres: ', trim(input_centres)
  if (id == 0) write(*, *) 'output_voids: ', trim(output_voids)
  if (id == 0) write(*, *) 'density_threshold: ', delta_char, 'Mpc^-3'
  if (id == 0) write(*, *) 'random_centres: ', nrc
  if (id == 0) write(*, *) 'gridmin: ', trim(gridmin_char), ' Mpc'
  if (id == 0) write(*, *) 'gridmax: ', trim(gridmax_char), ' Mpc'
  if (id == 0) write(*, *) 'rvoidmax: ', trim(rvoidmax_char), ' Mpc'
  if (id == 0) write(*,*) ''

  if (process_num .gt. 1) then
    output_voids = trim(output_voids) // '.' // trim(str(id))
  end if

  open(10, file=input_tracers, status='old', form='unformatted')
  read(10) ng
  allocate(pos_data(3, ng))
  read(10) pos_data
  close(10)
  if (id == 0) write(*,*) 'ntracers: ', trim(str(ng))
  
  open(11, file=input_randoms, status='old', form='unformatted')
  read(11) nr
  allocate(pos_rand(3, nr))
  read(11) pos_rand
  close(11)
  if (id == 0) write(*,*) 'nrandoms: ', trim(str(nr))

  open(12, file=input_centres, status='old')
  nc = 0
  do
    read(12, *, end=12)
    nc = nc + 1
  end do
  12 rewind(12)
  if (id == 0) write(*,*) 'n_centres: ', trim(str(nc))

  rgrid = (gridmax - gridmin) / ngrid
  rwidth = rvoidmax / nrbin
  ndif = int(rvoidmax / rgrid + 1)
  if (id == 0) write(*,*) 'rgrid: ', rgrid
  if (id == 0) write(*,*) 'ndif: ', ndif
  if (id == 0) write(*,*) 'rwidth: ', rwidth
  if (id == 0) write(*,*) ''

  allocate(ll_data(ng))
  allocate(ll_rand(nr))
  call linked_list(ngrid, rgrid, gridmin, gridmax, ll_data, lirst_data, pos_data)
  call linked_list(ngrid, rgrid, gridmin, gridmax, ll_rand, lirst_rand, pos_rand)

  filenumber = id + 20
  open(filenumber, file=output_voids, status='replace')

  do i = 1, nc
    read(12,*) px, py, pz, rvoid, ngv, nden

    pxr = px
    pyr = py
    pzr = pz
    rvoidr = rvoid

    if (id == 0 .and. mod(i, int(1e4)) .eq. 1) then
      write(*,*) 'Centre ', i,' out of ', nc
    end if

    if(mod(i, process_num) .eq. id) then

      stuck = 0
      do j = 1, nrc
        rbin_data = 0
        rbin_rand = 0
        crbin_data = 0
        crbin_rand = 0

        call random_number(rnd)
        rnd_phi = rnd * 2 * pi
        call random_number(rnd)
        rnd_theta = acos(rnd * 2 - 1)

        rnd_px = rvoid/4 * sin(rnd_theta) * cos(rnd_phi) + px
        rnd_py = rvoid/4 * sin(rnd_theta) * sin(rnd_phi) + py
        rnd_pz = rvoid/4 * cos(rnd_theta) + pz

        if (sqrt((rnd_px-pxr)**2 + (rnd_py-pyr)**2 + (rnd_pz-pzr)**2 )&
        & .gt. rvoidr) cycle

        ipx = int((rnd_px - gridmin) / rgrid + 1.)
        ipy = int((rnd_py - gridmin) / rgrid + 1.)
        ipz = int((rnd_pz - gridmin) / rgrid + 1.)

        do ix = ipx - ndif, ipx + ndif, 1
          do iy = ipy - ndif, ipy + ndif, 1
            do iz = ipz - ndif, ipz + ndif, 1

              if (sqrt(real((ix - ipx) ** 2 + (iy - ipy)** 2&
              & + (iz - ipz) ** 2)) .gt. ndif + 1) cycle

              ii = lirst_data(ix, iy, iz)
              if (ii .ne. 0) then
                do
                  ii = ll_data(ii)

                  disx = pos_data(1, ii) - rnd_px
                  disy = pos_data(2, ii) - rnd_py
                  disz = pos_data(3, ii) - rnd_pz

                  dis = sqrt(disx ** 2 + disy ** 2 + disz ** 2)

                  if (dis .lt. rvoidmax) then
                    rind = int(dis / rwidth + 1)
                    rbin_data(rind) = rbin_data(rind) + 1
                  end if

                  if (ii .eq. lirst_data(ix, iy, iz)) exit
                end do
              end if

              ii = lirst_rand(ix, iy, iz)
              if (ii .ne. 0) then
                do
                  ii = ll_rand(ii)

                  disx = pos_rand(1, ii) - rnd_px
                  disy = pos_rand(2, ii) - rnd_py
                  disz = pos_rand(3, ii) - rnd_pz

                  dis = sqrt(disx ** 2 + disy ** 2 + disz ** 2)

                  if (dis .lt. rvoidmax) then
                    rind = int(dis / rwidth + 1)
                    rbin_rand(rind) = rbin_rand(rind) + 1
                  end if

                  if (ii .eq. lirst_rand(ix, iy, iz)) exit
                end do
              end if
            end do
          end do
        end do

        stuck = stuck + 1

        rbin_rand = rbin_rand  / (nr * 1./ng)

        crbin_data(1) = rbin_data(1)
        crbin_rand(1) = rbin_rand(1)
        do ii = 2, nrbin
          crbin_data(ii) =  crbin_data(ii - 1) + rbin_data(ii)
          crbin_rand(ii) =  crbin_rand(ii - 1) + rbin_rand(ii)
        end do

        do ii = nrbin, 1, -1
          rnd_rvoid = rwidth * ii
          rnd_ngv = crbin_data(ii)
          rnd_nden = crbin_data(ii) / crbin_rand(ii)
          if (rnd_nden .le. delta .and. rnd_rvoid .gt. rvoid&
          & .and. rnd_ngv .gt. 0) then
            rvoid = rnd_rvoid
            px = rnd_px
            py = rnd_py
            pz = rnd_pz
            ngv = rnd_ngv
            nden = rnd_nden
            stuck = 0
            exit
          end if
        end do

        if (stuck .gt. 64) exit

      end do
      write(filenumber, '(4F10.3, 1I10, 1F10.3)') px, py, pz, rvoid, ngv, nden
    end if
  end do

  close(filenumber)
  deallocate(pos_data)
  deallocate(pos_rand)

  if (id == 0) write(*,*) ''

  call MPI_Finalize ( ierr )

end program recentring
