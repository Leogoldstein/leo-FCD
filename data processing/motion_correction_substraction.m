function [deviation, bad_frames, bad_frames_no_movement, bad_frames_with_movement, F] = ...
    motion_correction_substraction(F, ops, speed)

    
    F_clean = F;
    F_clean(:, bad_frames) = NaN;
    F_clean = fillmissing(F_clean, 'linear', 2, 'EndValues', 'nearest'); %interpolation
    F = F_clean;

end