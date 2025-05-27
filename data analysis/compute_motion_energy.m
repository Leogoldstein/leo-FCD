function motion_energy = compute_motion_energy(movie_path, xrange, yrange)
%COMPUTE_MOTION_ENERGY Compute normalized motion energy from a multi-frame TIFF movie (BigTIFF).
%   motion_energy = compute_motion_energy(movie_path)
%   motion_energy = compute_motion_energy(movie_path, xrange, yrange)
%
%   Parameters:
%   - movie_path: string, path to the TIFF stack (3D volume)
%   - xrange: 2-element vector for cropping columns [x_start, x_end] (optional)
%   - yrange: 2-element vector for cropping rows [y_start, y_end] (optional)

    if nargin < 2
        xrange = [];
    end
    if nargin < 3
        yrange = [];
    end

    % Load the full 3D TIFF volume (works for BigTIFF stacks)
    movie = tiffreadVolume(movie_path);  % size: height x width x frames
    [height, width, num_frames] = size(movie);

    fprintf('Loaded movie with %d frames, height=%d, width=%d\n', num_frames, height, width);

    % Optional cropping
    if ~isempty(yrange)
        movie = movie(yrange(1):yrange(2), :, :);
    end
    if ~isempty(xrange)
        movie = movie(:, xrange(1):xrange(2), :);
    end

    % Recompute dimensions after cropping
    [height, width, num_frames] = size(movie);

    % Pre-allocate motion energy array
    motion_energy = zeros(1, num_frames);

    % First frame
    img_prev = double(movie(:,:,1));

    for i = 2:num_frames
        img = double(movie(:,:,i));

        % Compute squared difference
        diff = img - img_prev;
        motion_energy(i) = sum(diff(:).^2);

        img_prev = img;

        if mod(i, 1000) == 0
            fprintf('Done computing for %d/%d frames\n', i, num_frames);
        end
    end

    % Normalize and return
    motion_energy = motion_energy(2:end);  % Skip first frame
    if max(motion_energy) > 0
        motion_energy = motion_energy / max(motion_energy);
    end
end
