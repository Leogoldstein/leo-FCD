function [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders,current_env_group)
    numFolders = length(gcamp_output_folders);
    all_recording_time = cell(numFolders, 1);
    all_optical_zoom = cell(numFolders, 1);
    all_position = cell(numFolders, 1);
    all_time_minutes = cell(numFolders, 1);

    for m = 1:length(gcamp_output_folders)
        [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(current_env_group{m});
        all_recording_time{m} = recording_time;
        all_optical_zoom{m} = optical_zoom;
        all_position{m} = position;
        all_time_minutes{m} = time_minutes; 
    end
end
