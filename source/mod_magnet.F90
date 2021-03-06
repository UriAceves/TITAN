module mod_magnet
  use mod_f90_kind, only: single,double
  use mod_parameters, only: dmax
  implicit none

  logical :: lfield
  !! Turn on/off static magnetic field
  integer                     :: iter
  !! self-consistency iteration
  real(double),allocatable    :: rho(:,:)
  !! orbital-dependent and d-orbital charge density per site
  real(double),allocatable    :: mx(:,:),my(:,:),mz(:,:)
  !! orbital-dependent magnetization per site in cartesian coordinates
  real(double),allocatable    :: rhod(:),mxd(:),myd(:),mzd(:)
  !! d-orbital charge density and magnetization per site
  complex(double),allocatable :: mp(:,:),mpd(:)
  !! circular components (plus) of the total and d-orbital magnetization
  real(double), dimension(:,:), allocatable :: rho0
  !! initial occupation per orbital obtained from hopping parameters only (to be used in the hamiltonian)
  real(double), dimension(:), allocatable :: rhod0
  !! initial occupation of d orbitals obtained from hopping parameters only (to be used in the hamiltonian)
  real(double),allocatable    :: lxm(:),lym(:),lzm(:)
  !! Orbital angular momentum in global frame of reference
  real(double),allocatable    :: lxpm(:),lypm(:),lzpm(:)
  !! Orbital angular momentum in local frame of reference
  real(double),allocatable    :: mabs(:),mtheta(:),mphi(:)
  !! Site-dependent spherical components of magnetization
  real(double), dimension(:,:),allocatable   :: mvec_spherical,mvec_cartesian
  !! Magnetization vectors in cartesian and spherical components
  real(double)                :: mtotal_cartesian(3),mtotal_spherical(3)
  !! Total magnetization in cartesian and spherical components
  real(double),allocatable    :: labs(:),ltheta(:),lphi(:)
  !! Site-dependent spherical components of orbital magnetization in global frame
  real(double),allocatable    :: lpabs(:),lptheta(:),lpphi(:)
  !! Site-dependent spherical components of orbital magnetization in local frame
  real(double), dimension(:,:), allocatable :: hhw
  !! Half of Static magnetic fields in each direction
  complex(double), dimension(:,:,:), allocatable :: lb, sb
  !! Zeeman matrices
  complex(double), dimension(:,:,:), allocatable :: lxp, lyp, lzp
  !! Site dependent Angular momentum matrices in local frame
  complex(double), dimension(:,:), allocatable   :: lx, ly, lz
  !! Angular momentum matrices in global frame
  complex(double), dimension(:,:,:), allocatable :: lvec
  !! Angular momentum vector matrices in global frame
  complex(double), dimension(:,:,:,:), allocatable :: lpvec
  !! Angular momentum vector matrices in local frame
  logical :: lrot = .false.
  !! Logical variable that indicates the need to rotate susceptibility matrix

  !========================================================================================!
  ! Values of magnetic field in cartesian or spherical coordinates
  !integer, parameter :: dmax = 20
  character(len=9), dimension(7) :: dcfield = ["hwa      ","hwt      ","hwp      ","hwahwt   ","hwahwp   ","hwthwp   ","hwahwthwp"]
  character(len=60) :: dc_header
  character(len=60), allocatable :: dc_fields(:),dcprefix(:)
  real(double), allocatable :: hw_list(:,:)
  integer :: dcfield_dependence = 0, dc_count = 0

  real(double) :: hwx = 0.d0, hwy = 0.d0, hwz = 0.d0, tesla = 1.d0

  integer :: hwa_npts = 0, hwa_npt1 = 1
  integer :: hwt_npts = 0, hwt_npt1 = 1
  integer :: hwp_npts = 0, hwp_npt1 = 1
  real(double) :: hwa, hwa_i = 0.d0, hwa_f = 0.d0, hwa_s = 0.d0
  real(double) :: hwt, hwt_i = 0.d0, hwt_f = 0.d0, hwt_s = 0.d0
  real(double) :: hwp, hwp_i = 0.d0, hwp_f = 0.d0, hwp_s = 0.d0

  ! Layer-resolved scale of magnetic field (including empty spheres)
  logical :: lhwscale        = .false.
  real(double) :: hwscale(dmax)   = 1.d0
  logical :: lhwrotate       = .false.
  real(double) :: hwtrotate(dmax) = 0.d0, hwprotate(dmax) = 0.d0

  integer :: skip_steps_hw = 0
  !! How many iterations are to be skipped from the beginning
  integer :: hw_count
  !! Current iteration of magnetic field loop.
  integer :: total_hw_npt1
  !! Total number of magnetic field iterations.

contains

  ! This subroutine sets up external magnetic fields and related loop
  subroutine setMagneticLoopPoints()
    use mod_constants, only: rad2deg
    implicit none
    !! Amount of points to skip
    integer       :: i, j, k, l

    if(lfield) then
      if (hwa_npts==0) then
        hwa_f = hwa_i
        hwa_npts = 1
      end if
      if((abs(hwa_i) + abs(hwa_f)) > 1.d-8) then
        if (hwt_npts==0) then
          hwt_f = hwt_i
          hwt_npts = 1
        end if
        if (hwp_npts==0) then
          hwp_f = hwp_i
          hwp_npts = 1
        end if
        ! External field angular loops steps
        hwa_s = (hwa_f - hwa_i)/hwa_npts
        if(abs(hwa_s) <= 1.d-10) hwa_npt1 = 1
        hwt_s = (hwt_f - hwt_i)/hwt_npts
        if(abs(hwt_s) <= 1.d-10) hwt_npt1 = 1
        hwp_s = (hwp_f - hwp_i)/hwp_npts
        if(abs(hwp_s) <= 1.d-10) hwp_npt1 = 1
      else ! hwa_i and hwa_f = 0
        hwa_i   = sqrt(hwx**2+hwy**2+hwz**2)
        hwa_f   = hwa_i
        if(abs(hwa_i)<1.d-8) then
          lfield = .false.
        else
          hwt_i    = acos(hwz/hwa_i)*rad2deg
          hwt_s    = 0.d0
          hwt_npt1 = 1
          hwp_i    = atan2(hwy,hwx)*rad2deg
          hwp_s    = 0.d0
          hwp_npt1 = 1
        end if
      end if
    else ! lfield
      hwa_i    = 0.d0
      hwa_f    = 0.d0
      hwa_s    = 0.d0
      hwa_npt1 = 1
      hwt_i    = 0.d0
      hwt_f    = 0.d0
      hwt_s    = 0.d0
      hwt_npt1 = 1
      hwp_i    = 0.d0
      hwp_f    = 0.d0
      hwp_s    = 0.d0
      hwp_npt1 = 1
    end if

    ! Total number of points in the loops
    total_hw_npt1 = hwa_npt1*hwt_npt1*hwp_npt1
    if(total_hw_npt1==1) skip_steps_hw = 0
    total_hw_npt1 = total_hw_npt1 - skip_steps_hw

    allocate(hw_list(total_hw_npt1,3))

    ! Creating list of magnetic fields (in spherical coordinates)
    i = 1
    do j = 1, hwa_npt1
      hwa = hwa_i + (j-1)*hwa_s
      do k=1, hwt_npt1
        hwt = hwt_i + (k-1)*hwt_s
        do l = 1, hwp_npt1
          if(i <= skip_steps_hw) cycle
          hwp = hwp_i + (l-1)*hwp_s
          hw_list(i - skip_steps_hw, :) = [ hwa , hwt , hwp ]
          i = i+1
        end do
      end do
    end do

  end subroutine setMagneticLoopPoints

  subroutine initMagneticField(nAtoms)
    use mod_f90_kind, only: double
    use mod_constants, only: cZero, deg2rad
    use mod_mpi_pars, only: abortProgram
    implicit none

    integer, intent(in) :: nAtoms
    integer :: i, AllocateStatus

    if(allocated(hhw)) deallocate(hhw)
    allocate( hhw(3,nAtoms), STAT = AllocateStatus )
    if (AllocateStatus /= 0) call abortProgram("[main] Not enough memory for: hhw")

    !---------------------- Turning off field for hwa=0 --------------------
    if(abs(hw_list(hw_count,1)) < 1.d-8) then
      lfield = .false.
    else
      lfield = .true.
    end if
    sb   = cZero
    lb   = cZero
    hhw  = 0.d0

    !--------------------- Defining the magnetic fields -------------------- TODO
    if(lfield) then
      ! Variables of the hamiltonian
      ! There is an extra  minus sign in the definition of hhw
      ! to take into account the fact that we are considering negative
      ! external fields to get the peak at positive energies
      do i = 1, nAtoms
        hhw(1,i) = -0.5d0*hwscale(i)*hw_list(hw_count,1)*sin((hw_list(hw_count,2) + hwtrotate(i))*deg2rad)*cos((hw_list(hw_count,3) + hwprotate(i))*deg2rad)*tesla
        hhw(2,i) = -0.5d0*hwscale(i)*hw_list(hw_count,1)*sin((hw_list(hw_count,2) + hwtrotate(i))*deg2rad)*sin((hw_list(hw_count,3) + hwprotate(i))*deg2rad)*tesla
        hhw(3,i) = -0.5d0*hwscale(i)*hw_list(hw_count,1)*cos((hw_list(hw_count,2) + hwtrotate(i))*deg2rad)*tesla
        !          ^ EXTRA MINUS SIGN
        if(abs(hhw(1,i))<1.d-8) hhw(1,i) = 0.d0
        if(abs(hhw(2,i))<1.d-8) hhw(2,i) = 0.d0
        if(abs(hhw(3,i))<1.d-8) hhw(3,i) = 0.d0
      end do
      ! Testing if hwscale is used
      lhwscale = any(abs(hwscale(1:nAtoms)-1.d0) > 1.d-8)
      ! Testing if hwrotate is used
      lhwrotate = (any(abs(hwtrotate(1:nAtoms)) > 1.d-8).or.any(abs(hwprotate(1:nAtoms))>1.d-8))
    end if
  end subroutine initMagneticField

  subroutine lb_matrix(nAtoms, nOrbs)
    use mod_f90_kind,   only: double
    use mod_constants,  only: cZero
    use mod_parameters, only: lnolb
    implicit none
    integer, intent(in) :: nOrbs, nAtoms
    integer :: i,sigma
    complex(double), dimension(:,:), allocatable :: lbsigma

    ! There is an extra  minus sign in the definition of hhw
    ! to take into account the fact that we are considering negative
    ! external fields to get the peak at positive energies
    lb = cZero
    if((lfield).and.(.not.lnolb)) then
      allocate(lbsigma(nOrbs, nOrbs))
      do i=1, nAtoms
        lbsigma = cZero
        ! L.B
        do sigma=1,3
          lbsigma(1:nOrbs, 1:nOrbs) = lbsigma(1:nOrbs, 1:nOrbs) + lvec(:,:,sigma)*hhw(sigma,i)
        end do
        lb(      1:  nOrbs,       1:  nOrbs, i) = lbsigma(:,:)
        lb(nOrbs+1:2*nOrbs, nOrbs+1:2*nOrbs, i) = lbsigma(:,:)
      end do
      deallocate(lbsigma)
    end if
  end subroutine lb_matrix


  ! Spin Zeeman hamiltonian
  subroutine sb_matrix(nAtoms, nOrbs)
    use mod_f90_kind, only: double
    use mod_constants, only: cZero, cI
    implicit none
    integer, intent(in) :: nAtoms, nOrbs
    integer :: i,mu,nu

    ! There is an extra  minus sign in the definition of hhw
    ! to take into account the fact that we are considering negative
    ! external fields to get the peak at positive energies
    sb = cZero

    if(lfield) then
      do i=1, nAtoms
        do mu=1,nOrbs
          nu=mu+nOrbs
          sb(mu,mu,i) = hhw(3,i)
          sb(nu,nu,i) =-hhw(3,i)
          sb(nu,mu,i) = hhw(1,i)-cI*hhw(2,i)
          sb(mu,nu,i) = hhw(1,i)+cI*hhw(2,i)
        end do
      end do
    end if
  end subroutine sb_matrix

  ! This subroutine calculate the orbital angular momentum matrix in the cubic system of coordinates
  subroutine l_matrix()
    use mod_f90_kind
    use mod_constants
    use mod_parameters, only: nOrb
    implicit none
    complex(double), dimension(nOrb,nOrb) :: Lp,Lm

    lz = cZero

    lz(2,3) = -cI
    lz(3,2) = cI

    lz(5,8) = 2.d0*cI
    lz(8,5) = -2.d0*cI
    lz(6,7) = cI
    lz(7,6) = -cI

    Lp = cZero
    Lm = cZero

    Lp(2,4) = -cOne
    Lp(3,4) = -cI
    Lp(4,2) = cOne
    Lp(4,3) = cI

    Lp(5,6) = -cOne
    Lp(5,7) = -cI

    Lp(6,5) = cOne
    Lp(6,8) = -cI
    Lp(6,9) = -sq3*cI

    Lp(7,5) = cI
    Lp(7,8) = cOne
    Lp(7,9) = -sq3

    Lp(8,6) = cI
    Lp(8,7) = -cOne

    Lp(9,6) = sq3*cI
    Lp(9,7) = sq3

    Lm = transpose(conjg(Lp))

    lx = 0.5d0*(Lp+Lm)
    ly = -0.5d0*cI*(Lp-Lm)

    lvec(:,:,1) = lx
    lvec(:,:,2) = ly
    lvec(:,:,3) = lz

  end subroutine l_matrix

  ! This subroutine calculate the orbital angular momentum matrix in the local system of coordinates
  subroutine lp_matrix(theta, phi)
    use mod_f90_kind, only: double
    use mod_constants, only: deg2rad
    use mod_System, only: s => sys
    implicit none
    real(double), dimension(s%nAtoms), intent(in) :: theta, phi
    integer :: i
    do i = 1, s%nAtoms
      lxp(:,:,i) = ( lvec(:,:,1)*cos(theta(i)*deg2rad)*cos(phi(i)*deg2rad)) + (lvec(:,:,2)*cos(theta(i)*deg2rad)*sin(phi(i)*deg2rad)) - (lvec(:,:,3)*sin(theta(i)*deg2rad))
      lyp(:,:,i) = (-lvec(:,:,1)                      *sin(phi(i)*deg2rad)) + (lvec(:,:,2)                      *cos(phi(i)*deg2rad))
      lzp(:,:,i) = ( lvec(:,:,1)*sin(theta(i)*deg2rad)*cos(phi(i)*deg2rad)) + (lvec(:,:,2)*sin(theta(i)*deg2rad)*sin(phi(i)*deg2rad)) + (lvec(:,:,3)*cos(theta(i)*deg2rad))

      lpvec(:,:,1,i) = lxp(:,:,i)
      lpvec(:,:,2,i) = lyp(:,:,i)
      lpvec(:,:,3,i) = lzp(:,:,i)
    end do
  end subroutine lp_matrix

  subroutine allocate_magnet_variables(nAtoms, nOrbs)
    use mod_mpi_pars, only: abortProgram
    implicit none
    integer, intent(in) :: nAtoms
    integer, intent(in) :: nOrbs
    integer :: AllocateStatus

    allocate( rho(nOrbs,nAtoms), stat = AllocateStatus)
    if(AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: rho")

    allocate( mx(nOrbs,nAtoms), my(nOrbs,nAtoms), mz(nOrbs,nAtoms), mp(nOrbs,nAtoms), &
              mvec_cartesian(3,nAtoms), &
              mvec_spherical(3,nAtoms), STAT = AllocateStatus )
    if (AllocateStatus/=0) call abortProgram("[allocate_magnet_variables] Not enough memory for: mx,my,mz,mp,mvec_cartesian,mvec_spherical")

    allocate( mxd(nAtoms), myd(nAtoms), mzd(nAtoms), mpd(nAtoms), &
              rhod(nAtoms), STAT = AllocateStatus )
    if (AllocateStatus/=0) call abortProgram("[allocate_magnet_variables] Not enough memory for: mx,my,mz,mp,mxd,myd,mzd,mvec_cartesian,mvec_spherical")

    allocate( mabs(nAtoms), mtheta(nAtoms), mphi(nAtoms), &
              labs(nAtoms), ltheta(nAtoms), lphi(nAtoms), &
              lpabs(nAtoms), lptheta(nAtoms), lpphi(nAtoms), STAT = AllocateStatus )
    if (AllocateStatus/=0) call abortProgram("[allocate_magnet_variables] Not enough memory for: mabs,mtheta,mphi,labs,ltheta,lphi,lpabs,lptheta,lpphi")

    allocate( hhw(3,nAtoms), STAT = AllocateStatus )
    if (AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: hhw")

    allocate(lx(nOrbs, nOrbs), ly(nOrbs,nOrbs), lz(nOrbs,nOrbs), lvec(nOrbs,nOrbs,3), stat = AllocateStatus)
    if (AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: lx, ly, lz, lvec")

    allocate(sb(2*nOrbs,2*nOrbs,nAtoms), stat = AllocateStatus)
    if (AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: sb")

    allocate(lb(2*nOrbs,2*nOrbs,nAtoms), stat = AllocateStatus)
    if (AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: lb")

    allocate(lxp(nOrbs,nOrbs,nAtoms), lyp(nOrbs,nOrbs,nAtoms), lzp(nOrbs,nOrbs,nAtoms), lpvec(nOrbs,nOrbs,3,nAtoms), stat = AllocateStatus)
    if (AllocateStatus /= 0) call abortProgram("[allocate_magnet_variables] Not enough memory for: lxp, lyp, lzp, lpvec")

  end subroutine allocate_magnet_variables

  subroutine deallocate_magnet_variables()
    implicit none

    if(allocated(rho)) deallocate(rho)
    if(allocated(mx)) deallocate(mx)
    if(allocated(my)) deallocate(my)
    if(allocated(mz)) deallocate(mz)
    if(allocated(mp)) deallocate(mp)
    if(allocated(mvec_cartesian)) deallocate(mvec_cartesian)
    if(allocated(mvec_spherical)) deallocate(mvec_spherical)
    if(allocated(mxd)) deallocate(mxd)
    if(allocated(myd)) deallocate(myd)
    if(allocated(mzd)) deallocate(mzd)
    if(allocated(mpd)) deallocate(mpd)
    if(allocated(rhod)) deallocate(rhod)
    if(allocated(mabs)) deallocate(mabs)
    if(allocated(mtheta)) deallocate(mtheta)
    if(allocated(mphi)) deallocate(mphi)
    if(allocated(labs)) deallocate(labs)
    if(allocated(ltheta)) deallocate(ltheta)
    if(allocated(lphi)) deallocate(lphi)
    if(allocated(lpabs)) deallocate(lpabs)
    if(allocated(lptheta)) deallocate(lptheta)
    if(allocated(lpphi)) deallocate(lpphi)
    if(allocated(hhw)) deallocate(hhw)
    if(allocated(lx)) deallocate(lx)
    if(allocated(ly)) deallocate(ly)
    if(allocated(lz)) deallocate(lz)
    if(allocated(lvec )) deallocate(lvec )
    if(allocated(sb)) deallocate(sb)
    if(allocated(lb)) deallocate(lb)
    if(allocated(lxp)) deallocate(lxp)
    if(allocated(lyp)) deallocate(lyp)
    if(allocated(lzp)) deallocate(lzp)
    if(allocated(lpvec)) deallocate(lpvec)

    if(allocated(lxm)) deallocate(lxm)
    if(allocated(lym)) deallocate(lym)
    if(allocated(lzm)) deallocate(lzm)
    if(allocated(lxpm)) deallocate(lxpm)
    if(allocated(lypm)) deallocate(lypm)
    if(allocated(lzpm)) deallocate(lzpm)
  end subroutine

  subroutine set_fieldpart(count)
    use mod_parameters, only: ltesla, lnolb, output
    use mod_tools,      only: rtos
    implicit none
    integer :: count

    output%BField = ""
    if(lfield) then
      write(output%BField, "('_hwa=',a,'_hwt=',a,'_hwp=',a)") trim(rtos(hw_list(count,1),"(es9.2)")),trim(rtos(hw_list(count,2),"(f7.2)")),trim(rtos(hw_list(count,3),"(f7.2)"))
      if(ltesla)    output%BField = trim(output%BField) // "_tesla"
      if(lnolb)     output%BField = trim(output%BField) // "_nolb"
      if(lhwscale)  output%BField = trim(output%BField) // "_hwscale"
      if(lhwrotate) output%BField = trim(output%BField) // "_hwrotate"
    end if

    output%dcBField = ""
    if(dcfield_dependence/=7) then
      if((dcfield_dependence/=1).and.(dcfield_dependence/=4).and.(dcfield_dependence/=5)) write(output%dcBField,"(a,'_hwa=',a)") trim(output%dcBField),trim(rtos(hwa,"(es9.2)"))
      if((dcfield_dependence/=2).and.(dcfield_dependence/=4).and.(dcfield_dependence/=6)) write(output%dcBField,"(a,'_hwt=',a)") trim(output%dcBField),trim(rtos(hwt,"(f7.2)"))
      if((dcfield_dependence/=3).and.(dcfield_dependence/=5).and.(dcfield_dependence/=6)) write(output%dcBField,"(a,'_hwp=',a)") trim(output%dcBField),trim(rtos(hwp,"(f7.2)"))
    end if
    if(ltesla)    output%dcBField = trim(output%dcBField) // "_tesla"
    if(lnolb)     output%dcBField = trim(output%dcBField) // "_nolb"
    if(lhwscale)  output%dcBField = trim(output%dcBField) // "_hwscale"
    if(lhwrotate) output%dcBField = trim(output%dcBField) // "_hwrotate"
  end subroutine set_fieldpart

end module mod_magnet
