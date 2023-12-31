#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "String";

build :: () {
    release_mode :: false;

    current_workspace := get_current_workspace();
    set_build_options_dc(.{do_output = false}, current_workspace);

    workspace := compiler_create_workspace("Multiplayer Example Server");
    build_options := get_build_options(workspace);
    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = "main";
    build_options.temporary_storage_size = 2097152;
    build_options.import_path = .["C:/jai/modules", #run tprint("%../../", #filepath), "/usr/jai/modules"];
    
    #if release_mode {
        set_optimization(*build_options, .VERY_OPTIMIZED);
    }

    print("Module folders: %\n", build_options.import_path);
    set_build_options(build_options, workspace);
    set_working_directory(#filepath);

    compiler_begin_intercept(workspace);
    defer compiler_end_intercept(workspace);

    // source files
    source_files := file_list(tprint("%src", #filepath), true);
    for file: source_files {
        if !ends_with(file, ".jai") {
            continue;
        }

        print("Build file: %\n", file);
        add_build_file(file, workspace);
    }

    // shared files
    shared_files := file_list(tprint("%../shared", #filepath), true);
    for file: shared_files {
        if !ends_with(file, ".jai") {
            continue;
        }

        print("Build file: %\n", file);
        add_build_file(file, workspace);
    }
    
    // default_check_message :: (message: *Message) -> valid: bool, complete: bool {
    //     if !message return false, false;
    //     if message.kind == .COMPLETE return false, true;
    //     return true, false;
    // }

    // check_message := default_check_message;
    // is_syntax_extension_compile := false;
    // if build_options.user_data_u64 {
    //     check_message = <<cast(*type_of(default_check_message)) build_options.user_data_u64;
    //     is_syntax_extension_compile = true;
    // }

    // if !is_syntax_extension_compile {
    //     // extra work when you're actually building like choosing build mode
    //     // that we want to skip when we're just using the compiler to parse the
    //     // codebase.
    // }

    // while true {
    //     message := compiler_wait_for_message();

    //     valid, complete := check_message(message);
    //     if complete break;
    //     if !valid continue;

    //     // do_what_you_want_with(message);
    // }
}

#run build();
