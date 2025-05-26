function motion_energy = compute_motion_energy(movie_path, xrange, yrange)
% COMPUTE_MOTION_ENERGY  Compute motion energy from a multi-frame TIFF movie.
%
% Parameters:
% - movie_path: Path to the multi-frame TIFF file (required for first run)
% - xrange: Range of x-values to crop the image (optional)
% - yrange: Range of y-values to crop the image (optional)
% - save_path: Path to save the motion energy result (optional)
   
    % Initialize motion energy
    movie = read_big_tiff(movie_path);  % <- this is your new custom function
    [height, width, num_frames] = size(movie);

    fprintf('Loaded movie with %d frames, height=%d, width=%d\n', num_frames, height, width);

    motion_energy = zeros(num_frames-1, 1);
    img_prev = movie(:,:,1);

    if nargin >= 2 && ~isempty(xrange)
        img_prev = img_prev(:, xrange);
    end
    if nargin >= 3 && ~isempty(yrange)
        img_prev = img_prev(yrange, :);
    end

    for i = 2:num_frames
        img = movie(:,:,i);

        if nargin >= 2 && ~isempty(xrange)
            img = img(:, xrange);
        end
        if nargin >= 3 && ~isempty(yrange)
            img = img(yrange, :);
        end

        diff = img - img_prev;
        squared_diff = diff .^ 2;
        motion_energy(i-1) = sum(squared_diff(:));

        img_prev = img;

        if mod(i, 1000) == 0
            fprintf('Done computing for %d/%d frames\n', i, num_frames);
        end
    end

    % Normalize and save
    if max(motion_energy) == 0
        warning('Motion energy is zero for all frames!');
    else
        motion_energy = motion_energy / max(motion_energy);
    end
end

function movie = read_big_tiff(tif_path)
    t = Tiff(tif_path, 'r');
    frame_idx = 1;

    while true
        img = double(t.read());
        if frame_idx == 1
            [h, w] = size(img);
            movie = zeros(h, w, 35850);  % préallocation pour vitesse : si taille connue
        end
        movie(:,:,frame_idx) = img;

        if t.lastDirectory()
            break;
        end

        t.nextDirectory();
        frame_idx = frame_idx + 1;
    end
    movie = movie(:,:,1:frame_idx); % au cas où 35850 est trop
    t.close();
end
