module local_routines 
    use global_mod, only: dp, ip, wall_elevation
    use domain_mod, only: domain_type
    implicit none
    
    real(dp), parameter:: bed_slope = 0.01_dp


    contains 

    subroutine set_initial_conditions_uniform_slope(domain)            
        class(domain_type), target, intent(inout):: domain
        integer(ip):: i,j
        real(dp):: x, y, cx, cy, slope

        ! Set elevation
        slope = bed_slope 

        cx = (domain%lw(1))*0.5
        cy = (domain%lw(2))*0.5
        do i = 1,domain%nx(1)
            do j = 1, domain%nx(2)
                x = (i-0.5_dp)*domain%dx(1) - cx
                y = (j-0.5_dp)*domain%dx(2) - cy 
                domain%u(i,j,4) = y*slope
            end do
        end do
        ! Wall boundaries along the sides and top
        domain%U(1,:,4) = wall_elevation 
        domain%U(domain%nx(1),:,4) = wall_elevation 
        domain%U(:,domain%nx(2),4) = wall_elevation 
        domain%U(:,1,4) = wall_elevation 

        ! Stage
        domain%U(:,:,1) = domain%U(:,:,4)

        ! Ensure stage >= elevation
        domain%U(:,:,1 ) = max(domain%U(:,:,1), domain%U(:,:,4))


        domain%manning_squared = 0.03_dp**2

    end subroutine


end module 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

program uniform_slope
    use global_mod, only: ip, dp, charlen
    use domain_mod, only: domain_type
    use file_io_mod, only: read_csv_into_array
    use local_routines
    implicit none

    integer(ip):: i, j
    real(dp):: last_write_time
    type(domain_type):: domain

    ! Approx timestep between outputs
    real(dp), parameter :: approximate_writeout_frequency = 60.0_dp
    real(dp), parameter :: final_time = 600.0_dp

    ! length/width
    real(dp), parameter, dimension(2):: global_lw = [50._dp, 1000._dp] 
    ! lower-left corner coordinate
    real(dp), parameter, dimension(2):: global_ll = [0._dp, 0._dp]
    ! grid size (number of x/y cells)
    integer(ip), parameter, dimension(2):: global_nx = [50, 1000] ! [400, 400] 

    ! Discharge of 1 cubic meter / second per metre width
    real(dp) :: discharge_per_unit_width = 1.0_dp
    real(dp) :: Qin, model_vd, model_d, model_v, theoretical_d, theoretical_v, theoretical_vol, model_vol


    ! This gives the inflow discharge per cell, where it is applied
    Qin = discharge_per_unit_width * (global_lw(1)/global_nx(1))

    domain%timestepping_method = 'rk2'

    ! Prevent dry domain from causing enormous initial step
    domain%maximum_timestep = 5.0_dp

    ! Allocate domain
    call domain%allocate_quantities(global_lw, global_nx, global_ll)

    ! call local routine to set initial conditions
    call set_initial_conditions_uniform_slope(domain)

    ! Trick to get the code to write out just after the first timestep
    last_write_time = -approximate_writeout_frequency

    ! Evolve the code
    do while (.true.)

        if(domain%time - last_write_time >= approximate_writeout_frequency) then

            last_write_time = last_write_time + approximate_writeout_frequency

            call domain%print()
            call domain%write_to_output_files()

            if (domain%time > final_time) then
                exit 
            end if

        end if

        call domain%evolve_one_step()

        ! Add discharge inflow
        domain%U(2:(domain%nx(1)-1), domain%nx(2)-1, 1) = &
            domain%U(2:(domain%nx(1)-1), domain%nx(2)-1, 1) + Qin*domain%evolve_step_dt / product(domain%dx)

    end do

    call domain%write_max_quantities()

    call domain%timer%print()


    theoretical_vol = Qin * domain%time * domain%lw(1) * (global_nx(1) - 2) * 1.0_dp / global_nx(1)
    model_vol = sum(domain%U(:,:,1) - domain%U(:,:,4)) * domain%dx(1) * domain%dx(2)
    ! Analytical solution
    ! vd = discharge_per_unit_width
    ! bed_slope = manning_squared * v * abs(v) / d^(4/3)
    ! bed_slope = manning_squared * discharge_per_unit_width**2 / (d^(10/3))
    ! d = (manning_squared * discharge_per_unit_width**2 / bed_slope )**(3/10)

    i = domain%nx(1)/2
    j = domain%nx(2)/2    
    model_vd = -1.0_dp * domain%U(i,j,3)    
    model_d = domain%U(i,j,1) - domain%U(i,j,4)
    model_v = model_vd/model_d

    theoretical_d = (domain%manning_squared(i,j) * discharge_per_unit_width**2 / bed_slope)**(3.0_dp/10.0_dp)

    print*, '## Testing ##'
    print*, ' '
    print*, '    Theoretical volume: ', theoretical_vol
    print*, '    Model volume: ', model_vol
    print*, '      error: ', theoretical_vol - model_vol
    if( abs(theoretical_vol - model_vol) < 1.0e-06_dp * theoretical_vol) then
        print*, 'PASS'
    else
        print*, 'FAIL: Mass conservation error', theoretical_vol, model_vol
    end if
    print*, ' '
    print*, '   Theoretical vd: ', discharge_per_unit_width
    print*, '   Model vd (near centre): ', model_vd
    if( abs(discharge_per_unit_width - model_vd) < 1.0e-05_dp*discharge_per_unit_width) then
        print*, 'PASS'
    else
        print*, 'FAIL: Flux error ', discharge_per_unit_width, model_vd
    end if

    print*, ' '
    print*, '   Theoretical d: ', theoretical_d
    print*, '   Model d: ', model_d
    if( abs(theoretical_d - model_d) < 1.0e-04_dp*theoretical_d) then
        print*, 'PASS'
    else
        print*, 'FAIL: Friction or steady flow error', theoretical_d, model_d
    end if

    call domain%finalise()    

end program
