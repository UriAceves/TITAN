subroutine create_folder()
  use mod_parameters, only: itype, strSites, lhfresponses
  use mod_SOC, only: SOCc
  implicit none

  integer :: i,j
  character(len=500) :: base_command = ""
  character(len=500) :: folder = ""
  character(len=500), dimension(4,2) :: chi_folder
  character(len=500), dimension(3) :: disturbance
  character(len=500), dimension(2) :: alpha
  character(len=500), dimension(3) :: currents
  write(base_command, "('mkdir -p ./results/',a1,'SOC/')") SOCc

  !! Create selfconsistency folder
  write(folder, "(a,'selfconsistency')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Go into layer dependent folder
  write(base_command, "(a,a,'/')") trim(base_command), trim(strSites)

  !! Create folder for Band Structure
  write(folder, "(a,'BS')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create Fermi Surface folder
  write(folder, "(a,'FS')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create LDOS folder
  write(folder, "(a,'LDOS')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create RPA and HF folder
  chi_folder(:,1) = ["HF/dm","HF/mm","HF/pm","HF/um"]
  chi_folder(:,2) = ["RPA/dm","RPA/mm","RPA/pm","RPA/um"]
  do i = 1, 2
    do j = 1, 4
      write(folder, "(a,a)") trim(base_command), trim(chi_folder(j,i))
      call execute_command_line(trim(folder))
    end do
  end do

  !! Create Alpha Folder
  alpha(:) = ["Slope", "TCM  "]
  do i = 1,2
    write(folder, "(a,'A/',a)") trim(base_command), trim(alpha(i))
    call execute_command_line(trim(folder))
  end do

  !! Create Disturbance Folder
  disturbance(:) = ["CD", "SD", "LD"]
  if(lhfresponses) disturbance(:) = ["CD_HF", "SD_HF", "LD_HF"]
  do i = 1,3
    write(folder, "(a,a)") trim(base_command), trim(disturbance(i))
    call execute_command_line(trim(folder))
  end do

  !! Create Torque folder
  write(folder, "(a,'SOT')") trim(base_command)
  if(lhfresponses) write(folder, "(a,'SOT_HF')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create Beff folder
  write(folder, "(a,'Beff')") trim(base_command)
  if(lhfresponses) write(folder, "(a,'Beff_HF')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create Jij folder
  write(folder, "(a,'Jij')") trim(base_command)
  call execute_command_line(trim(folder))

  !! Create currents folder
  currents(:) = ["CC", "SC", "LC"]
  if(lhfresponses) currents(:) = ["CC_HF", "SC_HF", "LC_HF"]
  do i = 1,3
    write(folder, "(a,a)") trim(base_command), trim(currents(i))
    call execute_command_line(trim(folder))
  end do

  !! Create SHA folder
  write(folder, "(a,'SHA')") trim(base_command)
  call execute_command_line(trim(folder))


  return
end subroutine create_folder