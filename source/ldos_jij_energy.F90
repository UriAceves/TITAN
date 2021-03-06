!   Calculates spin-resolved LDOS and energy-dependence of exchange interactions
subroutine ldos_jij_energy(e,ldosu,ldosd,Jijint)
  use mod_f90_kind,      only: double
  use mod_constants,     only: pi, cZero, cOne, pauli_dorb
  use mod_parameters,    only: nOrb, nOrb2, eta, U
  use mod_system,        only: s => sys
  use mod_BrillouinZone, only: realBZ
  use mod_magnet,        only: mvec_cartesian, mabs
  use mod_progress
  use mod_mpi_pars
  implicit none
  real(double),intent(in)     :: e
  real(double),intent(out)    :: ldosu(s%nAtoms, nOrb),ldosd(s%nAtoms, nOrb)
  real(double),intent(out)    :: Jijint(s%nAtoms,s%nAtoms,3,3)
  complex(double), dimension(nOrb2, nOrb2, s%nAtoms, s%nAtoms) :: gf
  complex(double), dimension(s%nAtoms, nOrb)   :: gfdiagu,gfdiagd
  complex(double), dimension(nOrb2, nOrb2)     :: gij,gji,temp1,temp2,paulia,paulib
  real(double),    dimension(:,:),allocatable     :: ldosu_loc,ldosd_loc
  real(double),    dimension(:,:,:,:),allocatable :: Jijint_loc
  real(double),    dimension(3) :: kp
  complex(double) :: paulimatan(3,3,nOrb2, nOrb2)
  real(double)    :: Jijkan(s%nAtoms,3,3), Jijk(s%nAtoms,s%nAtoms,3,3)
  real(double)    :: weight
  integer         :: i,j,mu,nu,alpha,ncount,ncount2
  integer*8       :: iz

  real(double),    dimension(3,s%nAtoms)               :: evec
  complex(double), dimension(s%nAtoms,3,nOrb2,nOrb2)   :: dbxcdm
  complex(double), dimension(s%nAtoms,3,3,nOrb2,nOrb2) :: d2bxcdm2
  complex(double), dimension(s%nAtoms,nOrb2,nOrb2)     :: paulievec

  ncount  = s%nAtoms*nOrb
  ncount2 = s%nAtoms*s%nAtoms*9

! (x,y,z)-tensor formed by Pauli matrices to calculate anisotropy term (when i=j)
  paulimatan = cZero
  paulimatan(1,1,:,:) = -pauli_dorb(3,:,:)
  paulimatan(2,2,:,:) = -pauli_dorb(3,:,:)
  paulimatan(1,3,:,:) = -pauli_dorb(1,:,:)
  paulimatan(3,1,:,:) = -pauli_dorb(1,:,:)
  paulimatan(2,3,:,:) = -pauli_dorb(2,:,:)
  paulimatan(3,2,:,:) = -pauli_dorb(2,:,:)

  ldosu = 0.d0
  ldosd = 0.d0
  Jijint = 0.d0

  do iz = 1, s%nAtoms
    ! Unit vector along the direction of the magnetization of each magnetic plane
    evec(:,iz) = [ mvec_cartesian(1,iz), mvec_cartesian(2,iz), mvec_cartesian(3,iz) ]/mabs(iz)

    ! Inner product of pauli matrix in spin and orbital space and unit vector evec
    paulievec(iz,:,:) = pauli_dorb(1,:,:) * evec(1,iz) + pauli_dorb(2,:,:) * evec(2,iz) + pauli_dorb(3,:,:) * evec(3,iz)

    do i = 1, 3
      ! Derivative of Bxc*sigma*evec w.r.t. m_i (Bxc = -U.m/2)
      dbxcdm(iz,i,:,:) = -0.5d0 * U(iz) * (pauli_dorb(i,:,:) - (paulievec(iz,:,:)) * evec(i,iz))

      ! Second derivative of Bxc w.r.t. m_i (Bxc = -U.m/2)
      do j=1,3
        d2bxcdm2(iz,i,j,:,:) = evec(i,iz)*pauli_dorb(j,:,:) + pauli_dorb(i,:,:)*evec(j,iz) - 3*paulievec(iz,:,:)*evec(i,iz)*evec(j,iz)
        if(i==j) d2bxcdm2(iz,i,j,:,:) = d2bxcdm2(iz,i,j,:,:) + paulievec(iz,:,:)
        d2bxcdm2(iz,i,j,:,:) = 0.5d0*U(iz)*d2bxcdm2(iz,i,j,:,:)/(mabs(iz))
      end do
    end do
  end do



  !$omp parallel default(none) &
  !$omp& private(iz,kp,weight,gf,gij,gji,paulia,paulib,i,j,mu,nu,alpha,gfdiagu,gfdiagd,Jijk,Jijkan,temp1,temp2,ldosu_loc,ldosd_loc,Jijint_loc) &
  !$omp& shared(s,realBZ,nOrb,nOrb2,e,eta,U,dbxcdm,d2bxcdm2,pauli_dorb,paulimatan,ldosu,ldosd,Jijint)
  allocate(ldosu_loc(s%nAtoms, nOrb), ldosd_loc(s%nAtoms, nOrb), Jijint_loc(s%nAtoms,s%nAtoms,3,3))
  ldosu_loc = 0.d0
  ldosd_loc = 0.d0
  Jijint_loc = 0.d0

  !$omp do schedule(static)
  do iz = 1, realBZ%workload
    kp = realBZ%kp(:,iz)
    weight = realBZ%w(iz)
    ! Green function on energy E + ieta, and wave vector kp
    call green(e,eta,s,kp,gf)

    ! Exchange interaction tensor
    Jijk   = 0.d0
    Jijkan = 0.d0
    do j = 1,s%nAtoms
      do i = 1,s%nAtoms
        gij = gf(:,:,i,j)
        gji = gf(:,:,j,i)
        do nu = 1,3
          do mu = 1,3
            paulia = dbxcdm(i,mu,:,:)
            paulib = dbxcdm(j,nu,:,:)
            call zgemm('n','n',nOrb2,nOrb2,nOrb2,cOne,paulia,nOrb2,gij,   nOrb2,cZero,temp1,nOrb2)
            call zgemm('n','n',nOrb2,nOrb2,nOrb2,cOne,temp1, nOrb2,paulib,nOrb2,cZero,temp2,nOrb2)
            call zgemm('n','n',nOrb2,nOrb2,nOrb2,cOne,temp2, nOrb2,gji,   nOrb2,cZero,temp1,nOrb2)
            ! Trace over orbitals and spins
            do alpha = 1,nOrb2
              Jijk(i,j,mu,nu) = Jijk(i,j,mu,nu) + real(temp1(alpha,alpha))
            end do
          end do
        end do

        ! Anisotropy (on-site) term
        if(i==j) then
          gij = gf(:,:,i,i)
          do nu = 1,3
            do mu = 1,3
              paulia = d2bxcdm2(i,mu,nu,:,:)
              call zgemm('n','n',nOrb2,nOrb2,nOrb2,cOne,gij,nOrb2,paulia,nOrb2,cZero,temp1,nOrb2)
              ! Trace over orbitals and spins
              do alpha = 1,nOrb2
                Jijkan(i,mu,nu) = Jijkan(i,mu,nu) + real(temp1(alpha,alpha))
              end do
              Jijk(i,i,mu,nu) = Jijk(i,i,mu,nu) + Jijkan(i,mu,nu)
            end do
          end do
        end if
      end do
    end do
    Jijint = Jijint + Jijk * weight

    ! Density of states
    do mu=1,nOrb
      do i=1,s%nAtoms
         nu=mu+nOrb
         gfdiagu(i,mu) = - aimag(gf(mu,mu,i,i))*weight
         gfdiagd(i,mu) = - aimag(gf(nu,nu,i,i))*weight
       end do
    end do

    ldosu_loc = ldosu_loc + gfdiagu
    ldosd_loc = ldosd_loc + gfdiagd
    Jijint_loc = Jijint_loc + Jijk

  end do
  !$omp end do nowait

  !$omp critical
    ldosu = ldosu + ldosu_loc
    ldosd = ldosd + ldosd_loc
    Jijint = Jijint + Jijint_loc
  !$omp end critical
  !$omp end parallel

  ldosu  = ldosu/pi
  ldosd  = ldosd/pi
  Jijint = Jijint/pi

  if(rFreq(1) == 0) then
     call MPI_Reduce(MPI_IN_PLACE, ldosu , ncount  , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
     call MPI_Reduce(MPI_IN_PLACE, ldosd , ncount  , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
     call MPI_Reduce(MPI_IN_PLACE, Jijint, ncount2 , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
  else
     call MPI_Reduce(ldosu , ldosu , ncount  , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
     call MPI_Reduce(ldosd , ldosd , ncount  , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
     call MPI_Reduce(Jijint, Jijint, ncount2 , MPI_DOUBLE_PRECISION, MPI_SUM, 0, FreqComm(1), ierr)
  end if
end subroutine ldos_jij_energy
