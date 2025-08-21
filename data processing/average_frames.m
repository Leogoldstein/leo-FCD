function avg_motion_energy = average_frames(motion_energy, avg_block)
    
    if isvector(motion_energy)
        motion_energy = motion_energy(:);
        motion_energy_length = length(motion_energy);
        new_length = floor(motion_energy_length / avg_block) * avg_block;
        motion_energy = motion_energy(1:new_length);

        reshaped = reshape(motion_energy, avg_block, []);
        avg_motion_energy = mean(reshaped, 1)';
    else
        [T, D] = size(motion_energy);
        new_length = floor(T / avg_block) * avg_block;
        motion_energy = motion_energy(1:new_length, :);

        reshaped = reshape(motion_energy, avg_block, [], D);
        avg_motion_energy = squeeze(mean(reshaped, 1));
    end

    fprintf('Congrats! New shape is %d\n', size(avg_motion_energy, 1));
end