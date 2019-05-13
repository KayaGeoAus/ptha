module local_routines 
    use global_mod, only: dp, ip, charlen, wall_elevation
    use domain_mod, only: domain_type, STG, UH, VH, ELV
    use read_raster_mod, only: gdal_raster_dataset_type
    use file_io_mod, only: count_file_lines
    use linear_interpolator_mod, only: linear_interpolator_type

    implicit none

    ! Hold some data for the boundary condition
    type :: boundary_information_type
        character(charlen):: bc_file
        real(dp), allocatable:: boundary_data(:,:)
        type(linear_interpolator_type):: gauge4_ts_function
        real(dp):: boundary_elev
        real(dp):: t0 = 0.0_dp
    end type

    ! This will hold the information -- is seen by other parts of the module
    type(boundary_information_type):: boundary_information

    contains 

    ! Read files with boundary condition info, and make a BC function
    subroutine setup_boundary_information(bc_file, boundary_elev)
        character(charlen), intent(in):: bc_file
        real(dp), intent(in):: boundary_elev

        integer(ip):: bc_unit, nr, nc, skip, i, extra

        boundary_information%bc_file = bc_file
        boundary_information%boundary_elev = boundary_elev
        open(newunit=bc_unit, file=bc_file)
        nr = count_file_lines(bc_unit)
        nc = 2
        skip = 1
        extra = 1 ! One more data point to avoid exceeding time 
        allocate(boundary_information%boundary_data(nr - skip + extra, nc))
        do i = 1, nr
            if(i > skip) then
                read(bc_unit, *) boundary_information%boundary_data(i - skip,:)
            else
                read(bc_unit, *) 
            end if 
        end do
        close(bc_unit)
        ! Extend the time-series with a constant value, so that time does not
        ! exceed model run time
        boundary_information%boundary_data(nr - skip + extra,1) = 1.0e+06_dp + &
            boundary_information%boundary_data(nr - skip + extra - 1, 1)

        boundary_information%boundary_data(nr - skip + extra,2) = &
            boundary_information%boundary_data(nr - skip + extra - 1, 2)

        call boundary_information%gauge4_ts_function%initialise(&
                boundary_information%boundary_data(:,1), boundary_information%boundary_data(:,2))
        boundary_information%t0 = boundary_information%boundary_data(1,1)

    end subroutine
    
    ! Make a function to evaluate the boundary at the domain
    !
    function boundary_function(domain, t, i, j) result(stage_uh_vh_elev)
        type(domain_type), intent(in):: domain
        real(dp), intent(in):: t
        integer(ip), intent(in) :: i, j
        real(dp):: stage_uh_vh_elev(4)
        real(dp) :: local_elev

        call boundary_information%gauge4_ts_function%eval([t + boundary_information%t0], stage_uh_vh_elev(1:1))
        
        local_elev = domain%U(i,j,4)
        if(local_elev > stage_uh_vh_elev(1)) then
            stage_uh_vh_elev(1) = local_elev
        end if
        stage_uh_vh_elev(2:3) = 0.0_dp
        stage_uh_vh_elev(4) = local_elev

    end function

    ! Main setup routine
    subroutine set_initial_conditions(domain)
        class(domain_type), target, intent(inout):: domain
        integer(ip):: i, j
        character(len=charlen):: input_elevation, input_stage
        real(dp), allocatable:: x(:), y(:)
        type(gdal_raster_dataset_type):: elevation_data, stage_data
        real(dp) :: wall
        real(dp) :: gauge_xy(3,3)

        ! Stage
        domain%U(:,:,STG) = 0.0e-0_dp

        ! Set elevation with the raster
        input_elevation = '../test_repository/BP07-DmitryN-Monai_valley_beach/Monai_bathymetry.tif'

        ! Make space for x/y coordinates, at which we will look-up the rasters
        allocate(x(domain%nx(1)), y(domain%nx(1)))
        x = domain%x
        call elevation_data%initialise(input_elevation)

        do j = 1, domain%nx(2)
            y = domain%y(j)
            call elevation_data%get_xy(x, y, domain%U(:,j,ELV), domain%nx(1), &
                bilinear=1_ip)
        end do

        deallocate(x,y)

        print*, 'Elevation range: ', minval(domain%U(:,:,ELV)), maxval(domain%U(:,:,ELV))

        ! Wall boundaries (without boundary conditions)
        wall = 0.3_dp
        domain%U(:,1,ELV) = wall
        domain%U(:,domain%nx(2),ELV) = wall
        domain%U(domain%nx(1),:,ELV) = wall

        if(domain%timestepping_method /= 'linear') then
            domain%manning_squared = 0.01_dp * 0.01_dp
        end if

        ! Ensure stage >= elevation
        domain%U(:,:,STG) = max(domain%U(:,:,STG), domain%U(:,:,ELV) + 1.0e-07_dp)

        ! Gauges
        gauge_xy(1:3, 1) = [4.521_dp, 1.196_dp, 5.0_dp]
        gauge_xy(1:3, 2) = [4.521_dp, 1.696_dp, 7.0_dp]
        gauge_xy(1:3, 3) = [4.521_dp, 2.196_dp, 9.0_dp]
        call domain%setup_point_gauges(xy_coords = gauge_xy(1:2,:), gauge_ids=gauge_xy(3,:))

    end subroutine

end module 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

program monai

    use global_mod, only: ip, dp, minimum_allowed_depth
    use domain_mod, only: domain_type
    use multidomain_mod, only: multidomain_type, setup_multidomain, test_multidomain_mod
    use boundary_mod, only: boundary_stage_transmissive_normal_momentum
    use local_routines
    use timer_mod
    use logging_mod, only: log_output_unit
    implicit none

    ! Useful misc variables
    integer(ip):: j, i, i0, j0, centoff, nd, lg
    real(dp):: last_write_time, gx(4), gy(4)

    ! Type holding all domains 
    type(multidomain_type) :: md

    type(timer_type) :: program_timer

    real(dp), parameter :: mesh_refine = 1.0_dp ! Increase resolution by this amount
    
    real(dp) ::  global_dt = 8.0E-03_dp / mesh_refine

    ! Approx timestep between outputs
    real(dp) :: approximate_writeout_frequency = 0.05_dp
    real(dp) :: final_time = 35.0_dp

    character(len=charlen) ::  bc_file = '../test_repository/BP07-DmitryN-Monai_valley_beach/Benchmark_2_input.txt'
    real(dp) :: bc_elev

    ! Length/width
    real(dp), dimension(2):: global_lw = [5.49_dp, 3.39_dp]
    ! Lower-left corner coordinate
    real(dp), dimension(2):: global_ll = [0.0_dp, 0.0_dp]
    ! grid size (number of x/y cells)
    integer(ip), dimension(2):: global_nx = [225_ip, 171_ip] * mesh_refine

    ! Inner domain 
    integer(ip) :: nest_ratio = 3_ip
    real(dp) :: high_res_ll(2) = [3.00_dp, 1.0_dp]
    real(dp) :: high_res_ur(2) = [5.25_dp, 2.7_dp]

    call program_timer%timer_start('setup')

    ! nd domains in this model
    nd = 2
    allocate(md%domains(nd))

    !
    ! Setup basic metadata
    !

    ! Main domain
    md%domains(1)%lower_left =global_ll
    md%domains(1)%lw = global_lw
    md%domains(1)%nx = global_nx
    md%domains(1)%dx = md%domains(1)%lw/md%domains(1)%nx
    md%domains(1)%timestepping_refinement_factor = 1_ip
    md%domains(1)%dx_refinement_factor = 1.0_dp
    md%domains(1)%timestepping_method = 'rk2'

    print*, 1, ' lw: ', md%domains(1)%lw, ' ll: ', md%domains(1)%lower_left, ' dx: ', md%domains(1)%dx, &
        ' nx: ', md%domains(1)%nx

    ! A detailed domain [Cannot partially share a physical boundary with the outer domain]
    call md%domains(2)%match_geometry_to_parent(&
        parent_domain=md%domains(1), &
        lower_left=high_res_ll, &
        upper_right=high_res_ur, &
        dx_refinement_factor=nest_ratio, &
        timestepping_refinement_factor=nest_ratio)
    md%domains(2)%timestepping_method = 'rk2'

    print*, 2, ' lw: ', md%domains(2)%lw, ' ll: ', md%domains(2)%lower_left, ' dx: ', md%domains(2)%dx, &
        ' nx: ', md%domains(2)%nx

    ! Allocate domains and prepare comms
    call md%setup()

    ! Initial conditions
    do j = 1, size(md%domains)
        call set_initial_conditions(md%domains(j))
    end do

    ! Build boundary conditions
    bc_elev = minval(md%domains(1)%U(:,:,4)) 
    call setup_boundary_information(bc_file, bc_elev)
    ! Boundary
    md%domains(1)%boundary_subroutine => boundary_stage_transmissive_normal_momentum
    md%domains(1)%boundary_function => boundary_function

    call md%make_initial_conditions_consistent()
    
    ! NOTE: For stability in 'null' regions, we set them to 'high land' that
    ! should be inactive. 
    call md%set_null_regions_to_dry()

    ! Print the gravity-wave CFL limit, to guide timestepping
    do j = 1, size(md%domains)
        print*, 'domain: ', j, 'ts: ', &
            md%domains(j)%linear_timestep_max()
    end do

    ! Trick to get the code to write out just after the first timestep
    last_write_time = -approximate_writeout_frequency

    print*, 'End setup'
    call program_timer%timer_end('setup')
    call program_timer%timer_start('evolve')

    ! Evolve the code
    do while (.true.)
        
        ! IO 
        if(md%domains(1)%time - last_write_time >= approximate_writeout_frequency) then
            call program_timer%timer_start('IO')
            call md%print()
            do j = 1, nd
                call md%domains(j)%write_to_output_files()
                call md%domains(j)%write_gauge_time_series()
            end do
            last_write_time = last_write_time + approximate_writeout_frequency
            call program_timer%timer_end('IO')
        end if

        call md%evolve_one_step(global_dt)

        if (md%domains(1)%time > final_time) exit
    end do

    call program_timer%timer_end('evolve')
    call md%finalise_and_print_timers

    print*, ''
    call program_timer%print(output_file_unit=log_output_unit)

end program
