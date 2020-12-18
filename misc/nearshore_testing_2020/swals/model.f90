!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Module "local_routines" with various helper subroutines.
#include "model_local_routines.f90"
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

program run_model
    !!
    !! A global-to-local model with various high-res sites around Australia.
    !!
    !! Basic usage involves these commandline arguments (designed for a particular study):
    !!     ./model stage_file rise_time model_name run_type load_balance_file offshore_solver_type offshore_manning highres_regions
    !!
    !! where the arguments are:
    !!     stage_file (raster filename with stage perturbation)
    !!     rise_time (time in seconds over which stage perturbation is applied. Can be 0.0 for instantaneous)
    !!     model_name (this will be included within the output_folder name -- use it to help identify outputs)
    !!     run_type (either 'test' or 'test_load_balance' or 'full'):
    !!         'full' is used to run a proper model; 
    !!         the other cases run short models using the load_balance_file ('test_load_balance') or not using any
    !!         load balancing ('test'). These are useful to produce outputs required to make a load_balance_file.
    !!     load_balance_file (file with load balancing metadata. Make it empty '' to use crude defaults)
    !!     offshore_solver_type ( 'linear_with_manning' or 'leapfrog_nonlinear' or 'linear_with_linear_friction' or
    !!         'linear_with_reduced_linear_friction' or 'linear_with_delayed_linear_friction' or 'linear_with_no_friction') ). 
    !!          Used to test different deep-ocean propagation approaches. 
    !!     offshore_manning (manning coefficient for offshore solver if using 'linear_with_manning' or 'leapfrog_nonlinear')"
    !!     highres_regions (either 'none' [global domain only] or 'australia' [uses all highres areas] or 
    !!         'NSW' [only use NSW high-res domains])
    !!
    !! The geometry of the domains is specified in this program.
    !!

    !
    ! Imports from SWALS 
    !
    use global_mod, only: ip, dp, charlen
        ! Integer/real precision and default character length
    use domain_mod, only: STG, UH, VH, ELV
        ! Indices of stage, depth-integrated velocities 
        ! (UH = east, VH = north) and elevation in the domain%U array.
    use multidomain_mod, only: multidomain_type
        ! The main type that holds all domains and evolves them
    use coarray_intrinsic_alternatives, only: swals_mpi_init, swals_mpi_finalize 
        ! Call at the beginning/end to ensure mpi starts and finishes. 
        ! Does nothing if not compiled for distributed parallel
    use timer_mod, only: timer_type
        ! For local timing of the code
    use logging_mod, only: log_output_unit
        ! Write messages to log_output_unit
    use stop_mod, only: generic_stop
        ! For halting when an error occurs (works in serial or parallel, tries 
        ! to close files, etc).

    !
    ! Case specific helper routines
    !
    use local_routines, only: set_initial_conditions, parse_commandline_args

    implicit none

    type(multidomain_type) :: md
        ! md is the main object -- holds all domains, evolves them, etc.

    type(timer_type) :: program_timer
        ! Local code-timing object

    real(dp), parameter:: global_lw(2) = [360.0_dp, 147.0_dp] 
        ! Length/width of multidomain in degrees lon,lat
    real(dp), parameter:: global_ll(2) = [-40.0_dp, -79.0_dp]
        ! Lower-left corner coordinate of multidomain in degrees lon,lat

    integer(ip), parameter :: mesh_refine = 4_ip 
        ! Increase this to decrease the cell side-length by mesh_refine 
        ! (i.e. for convergence testing). 4_ip --> 1 arcmin in the coarse 
        ! global domain

    real(dp), parameter ::  global_dt = 6.0_dp * (1.0_dp/mesh_refine) 
        ! The global time-step in the multidomain. Must satisfy CFL condition 
        ! everywhere (in combination with local timestepping that is specified
        ! when defining the domains below)
    real(dp), parameter :: approximate_writeout_timestep = 30.0_dp
        ! Approx timestep between any outputs (in this case, tide-gauge outputs)
    integer(ip), parameter :: write_grids_every_nth_step = 360_ip
        ! Optionally write grids less often than the writeout timestep, to keep file-size down
    integer(ip), parameter :: print_every_nth_step = 10_ip
        ! Optionally print outputs less often than the writeout timestep, to keep the file-size down
    integer(ip), parameter :: write_gauges_every_nth_step = 1_ip
        ! Optionally write gauges less often than the writeout timestep, to keep the file-size down

    real(dp), parameter :: seconds_before_evolve = 0.0_dp 
        ! Non-global domains might not need to evolve at the start -- this specifies 
        ! the time before which they evolve. Crude approach (could be domain
        ! specific).

    integer(ip), parameter :: nd_global = 4, &
                              nd_nsw = 8, nd_victoria = 2, nd_perth = 2
        ! Number of domains in different regions.

    real(dp) :: final_time
        ! Duration of simulation in seconds (start_time = 0.0_dp)

    integer(ip):: j, nd, nsw_regional, vic_regional, perth_regional, global_main
        ! Useful misc local variables
    character(len=charlen) :: stage_file, model_name, run_type, &
        offshore_solver_type, highres_regions
        ! For reading commandline
    real(dp) :: linear_friction_delay_time, linear_friction_delay_value
        ! For case with linear friction after some time

    call swals_mpi_init 
        ! Ensure MPI is initialised

#ifndef SPHERICAL
    write(log_output_unit,*) &
        'Code assumes spherical coordinates, but SPHERICAL is not defined'
    call generic_stop
#endif

    ! 
    call parse_commandline_args(stage_file, run_type, final_time, model_name, &
        md%load_balance_file, offshore_solver_type, md%output_basedir, &
        highres_regions)

    !
    ! Basic definition of multidomain
    !

    call program_timer%timer_start('startup_define_multidomain_geometry')

    ! Figure out how many domains are needed
    if(highres_regions == 'none') then
        ! Do not use any of the regional or high-res domains
        nd = nd_global
    else if(highres_regions == 'australia') then
        ! High res domains everywhere
        nd = nd_global + nd_nsw + nd_victoria + nd_perth
    else if(highres_regions == 'NSW') then
        ! High res domains in NSW only - plus include regional Victoria domain
        ! so that edge-waves can propagate well around that coast
        nd = nd_global + nd_nsw + 1
    end if
        ! nd domains in this model
    allocate(md%domains(nd))

    md%periodic_xs = [global_ll(1), global_ll(1) + global_lw(1)]
        ! This will enforce periodic EW boundary condition as the values equal
        ! the x-range of the multidomain

    !
    ! Setup domain metadata
    !

    do j = 1, nd_global
        ! Global linear domain, split into 4 pieces by longitude
        ! This is used for all model types

        md%domains(j)%lw = [global_lw(1)*1.0_dp/nd_global, global_lw(2)]
        md%domains(j)%lower_left = &
            [global_ll(1) + (j-1)*global_lw(1)*1.0_dp/nd_global, global_ll(2)]
        md%domains(j)%dx = 1/60.0_dp * 4.0_dp * [1.0_dp, 1.0_dp] / mesh_refine 
        md%domains(j)%nx = nint(md%domains(j)%lw/md%domains(j)%dx)
        md%domains(j)%dx_refinement_factor = 1.0_dp
        md%domains(j)%timestepping_refinement_factor = 1_ip
        md%domains(j)%nc_grid_output%spatial_stride = 4_ip 
            ! Reduce output file size by only saving every n'th cell 

        ! A few options for the type of offshore solver
        select case(offshore_solver_type)
        case ("linear_with_manning")
            md%domains(j)%timestepping_method = 'leapfrog_linear_plus_nonlinear_friction'
            md%domains(j)%linear_solver_is_truely_linear = .true.
            ! Try Chezy friction in the offshore domains only -- more energy loss. 
            ! md%domains(j)%friction_type = 'chezy'
        case ("linear_with_linear_friction")
            md%domains(j)%timestepping_method = 'linear' 
            md%domains(j)%linear_friction_coeff = 1.0e-05_dp
            md%domains(j)%linear_solver_is_truely_linear = .true.
        case ("linear_with_reduced_linear_friction")
            md%domains(j)%timestepping_method = 'linear' 
            md%domains(j)%linear_friction_coeff = 1.0_dp/(36.0_dp*3600.0_dp)
            md%domains(j)%linear_solver_is_truely_linear = .true.
        case ("linear_with_delayed_linear_friction")
            md%domains(j)%timestepping_method = 'linear' 
            md%domains(j)%linear_friction_coeff = 0.0_dp ! Later change to 1e-05_dp
            md%domains(j)%linear_solver_is_truely_linear = .true.
            ! Apply linear friction after 12 hours
            linear_friction_delay_time = 12.0_dp * 3600.0_dp 
            linear_friction_delay_value = 1.0e-05_dp
        case ("linear_with_no_friction")
            md%domains(j)%timestepping_method = 'linear' 
            md%domains(j)%linear_friction_coeff = 0.0e-05_dp
            md%domains(j)%linear_solver_is_truely_linear = .true.
        case ("leapfrog_nonlinear")
            md%domains(j)%timestepping_method = 'leapfrog_nonlinear'
        case default
            write(log_output_unit,*) 'Unrecognized offshore_solver_type'
            call generic_stop
        end select

    end do

    ! Below here, the domains are nonlinear. In each region we've got a
    ! regional domain containing one or more high-res nested domains.

    if(any(highres_regions == [character(len=charlen):: &
           'australia', 'NSW'] )) then

        !
        ! NSW high-res domains (+ regional victoria, as it might affect NSW in
        ! the east) 
        !
        
        nsw_regional = nd_global + 1 
        call md%domains(nsw_regional)%match_geometry_to_parent(&
            ! Better-than-global resolution domain for NSW
            parent_domain=md%domains(3), &
            lower_left  = [149.25_dp, -38.5_dp], &
            upper_right = [152.5_dp, -32.0_dp], &
            dx_refinement_factor = 7_ip, &
            timestepping_refinement_factor = 4_ip, &!3_ip ,& 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional)%timestepping_method = 'rk2' 
        md%domains(nsw_regional)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional)%static_before_time = seconds_before_evolve
        
        call md%domains(nsw_regional+1)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Hawkesbury
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.85_dp, -33.75_dp], &
            upper_right = [151.60_dp, -33.40_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 4_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+1)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+1)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+1)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+2)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Sydney
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.85_dp, -34.2_dp], &
            upper_right = [151.40_dp, -33.75_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 5_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+2)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+2)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+2)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+3)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Port Kembla
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.84_dp, -34.6_dp], &
            upper_right = [151.10_dp, -34.35_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 5_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+3)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+3)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+3)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+4)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Jervis Bay
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.62_dp, -35.22_dp], &
            upper_right = [150.90_dp, -34.86_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 4_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+4)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+4)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+4)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+5)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Ulladullah
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.44_dp, -35.40_dp], &
            upper_right = [150.60_dp, -35.26_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 4_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+5)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+5)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+5)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+6)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Batemans Bay
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [150.08_dp, -35.8_dp], &
            upper_right = [150.35_dp, -35.6_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 4_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+6)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+6)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+6)%static_before_time = seconds_before_evolve

        call md%domains(nsw_regional+7)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Eden
            parent_domain=md%domains(nsw_regional), &
            lower_left  = [149.85_dp, -37.13_dp], &
            upper_right = [150._dp, -37.0_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 3_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(nsw_regional+7)%timestepping_method = 'rk2' 
        md%domains(nsw_regional+7)%nc_grid_output%spatial_stride = 1
        if(run_type == 'full') &
            md%domains(nsw_regional+7)%static_before_time = seconds_before_evolve

        !
        ! Regional Victoria domain
        !
        vic_regional = nd_global + nd_nsw + 1
        call md%domains(vic_regional)%match_geometry_to_parent(&
            ! Better-than-global domain for Victoria -- actually this will nest with md%domains(3), but
            ! there is no impact of specifying md%domains(2) because it has the same grid-alignment as md%domains(3),
            ! so we correctly round onto a whole cell.
            parent_domain=md%domains(2), & 
            lower_left = [141.0_dp, -41.25_dp], &
            upper_right = [149.25_dp, -37.3_dp], &
            dx_refinement_factor = 7_ip, &
            timestepping_refinement_factor = 4_ip, &
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(vic_regional)%timestepping_method = 'rk2'
        md%domains(vic_regional)%nc_grid_output%spatial_stride = 1 
        if(run_type == 'full') &
            md%domains(vic_regional)%static_before_time = seconds_before_evolve

    end if

    if(highres_regions == 'australia') then
        !! Only include WA + highres Vic if we are doing an 'australia-wide'
        !! model. For many events we only have tidal-gauge data in NSW, and
        !! in those cases this is a waste of compute

        call md%domains(vic_regional+1)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain Portland 
            parent_domain=md%domains(vic_regional), &
            lower_left = [141.45_dp, -38.5_dp], &
            upper_right = [141.75_dp, -38.22_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 4_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(vic_regional+1)%timestepping_method = 'rk2'
        md%domains(vic_regional+1)%nc_grid_output%spatial_stride = 1 
        if(run_type == 'full') &
            md%domains(vic_regional+1)%static_before_time = seconds_before_evolve


        !
        ! Regional Perth domain
        !
        perth_regional = nd_global + nd_nsw + nd_victoria + 1
        call md%domains(perth_regional)%match_geometry_to_parent(&
            ! Better-than-global res domain around SW WA.
            parent_domain=md%domains(2), &
            lower_left = [114.0_dp, -36.0_dp], &
            upper_right = [116.3_dp, -30.0_dp], &
            dx_refinement_factor = 7_ip, &
            timestepping_refinement_factor = 5_ip, &
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(perth_regional)%timestepping_method = 'rk2'
        md%domains(perth_regional)%nc_grid_output%spatial_stride = 1 
        if(run_type == 'full') &
            md%domains(perth_regional)%static_before_time = seconds_before_evolve

        call md%domains(perth_regional+1)%match_geometry_to_parent(&
            ! Higher-res nonlinear domain around Hillarys/Perth
            parent_domain=md%domains(perth_regional), &
            lower_left = [115.6_dp, -32.35_dp], &
            upper_right = [115.9_dp, -31.4_dp], &
            dx_refinement_factor = 7_ip, & 
            timestepping_refinement_factor = 2_ip, & 
            rounding_method='nearest', &
            recursive_nesting=.false.)
        md%domains(perth_regional+1)%timestepping_method = 'rk2'
        md%domains(perth_regional+1)%nc_grid_output%spatial_stride = 1 
        if(run_type == 'full') &
            md%domains(perth_regional+1)%static_before_time = seconds_before_evolve
    end if

    ! Minor adjustments to domains
    do j = 1, size(md%domains)

        md%domains(j)%nc_grid_output%time_var_store_flag(STG:VH) = .true.
        md%domains(j)%nc_grid_output%time_var_store_flag(ELV) = .false.
            ! Store stage/UH/VH grids over time, but not ELEVATION (it will 
            ! be stored once anyway).

        md%domains(j)%theta = 4.0_dp
            ! Use "non-TVD" limiting in nonlinear domains. Less dissipative.
    end do

    call program_timer%timer_end('startup_define_multidomain_geometry')

    !
    ! Setup the multidomain object
    !
    call program_timer%timer_start('startup_md_setup')

    call md%setup()
        ! Allocate domains and prepare comms
    call program_timer%timer_end('startup_md_setup')

    !
    ! Read initial conditions and make them consistent with each other
    !
    call program_timer%timer_start('startup_set_initial_conditions')
    do j = 1, size(md%domains)
        call set_initial_conditions(md%domains(j), stage_file)
    end do
    call md%memory_summary()
    call md%make_initial_conditions_consistent()
        ! Perform a parallel halo exchange so initial conditions are consistent.

    call md%set_null_regions_to_dry()
        ! Set 'null' regions (i.e. non-halo areas where other domains have 
        ! priority) to 'high/dry land' that will be inactive. This enhances 
        ! stability. Such regions cannot interact with priority regions
        ! (because the halo update prevents it).

    call program_timer%timer_end('startup_set_initial_conditions')
  
    !
    ! Gauges 
    ! 
    call program_timer%timer_start('startup_set_gauges')
    call md%set_point_gauges_from_csv("point_gauges_combined.csv", &
        skip_header=1_ip)
    call program_timer%timer_end('startup_set_gauges')
  
    !
    ! Final setup work.
    ! 
    call program_timer%timer_start('startup_end')

    call md%record_initial_volume()
        ! For mass conservation checks

    do j = 1, size(md%domains)
        write(log_output_unit,*) 'domain: ', j, 'ts: ', &
            md%domains(j)%stationary_timestep_max()
            ! Print the gravity-wave CFL limit to guide timestepping
        call md%domains(j)%timer%reset
            ! Reset the domain timers, so that load-balancing only sees the 
            ! evolve info
    end do

    write(log_output_unit,*) 'End setup'
    call program_timer%timer_end('startup_end')
    
    flush(log_output_unit)

    !
    ! Main evolve loop
    !

    do while (.true.)

        call program_timer%timer_start('IO')
        call md%write_outputs_and_print_statistics(&
            ! Print and write outputs
            approximate_writeout_frequency=approximate_writeout_timestep, &
                ! Time between writes is ~= "approximate_writeout_timestep"
            write_grids_less_often = write_grids_every_nth_step, &
                ! Write gridded outputs less often
            write_gauges_less_often = write_gauges_every_nth_step, &
                ! Write gauges every time 
            print_less_often = print_every_nth_step, & !1_ip,&
                ! Print domain statistics less often 
            timing_tol = (global_dt/2.01_dp))
        call program_timer%timer_end('IO')

        if (md%domains(1)%time > final_time) exit

        if(offshore_solver_type == 'linear_with_delayed_linear_friction') then
            ! Set the linear friction coefficient if the delay time has been exceeded
            if(md%domains(1)%time > linear_friction_delay_time) then
                do j = 1, size(md%domains)
                    if(md%domains(j)%timestepping_method == 'linear') then
                        md%domains(j)%linear_friction_coeff = linear_friction_delay_value
                    end if
                end do
            end if
        end if

        call program_timer%timer_start('evolve')
        call md%evolve_one_step(global_dt)
            ! Evolve the model by global_dt seconds
        call program_timer%timer_end('evolve')

    end do

    call md%finalise_and_print_timers
        ! Close files and print timing info (required for load balancing)

    write(log_output_unit,*) ''
    write(log_output_unit, *) 'Program timer'
    write(log_output_unit, *) ''
    call program_timer%print(log_output_unit)
    flush(log_output_unit)

    call swals_mpi_finalize

end program
