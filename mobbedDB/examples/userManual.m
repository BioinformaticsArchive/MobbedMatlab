%% 2.1 creating a database named shooter
Mobbed.createdb('shooter', 'localhost', 'postgres', 'admin', 'mobbed.sql');

%% 2.2 creating a database named shooter
try
    Mobbed.createdb('shooter', 'localhost', ...
        'postgres', 'admin', 'mobbed.sql')
catch me   % if database already exists, creation fails and warns
    warning('mobbed:creationfailed', me.message);
end

%% 3.1 deleting a database named shooter
Mobbed.deletedb('shooter', 'localhost', 'postgres', 'admin');

%% 4.1 connecting to a database named shooter
DB = Mobbed('shooter', 'localhost', 'postgres', 'admin');

%% 5.1 disconnecting from a database
close(DB);

%% 6.1 upload EEGLAB EEG structure to database
load eeglab_data_ch.mat;             % load a previously saved EEG structure
s = db2mat(DB);                      % get empty structure to fill in
s.dataset_name = 'eeglab_data';      % dataset name is required
s.data = EEG;                        % set data to be stored
sUUID = mat2db(DB, s);

%% 6.2 upload tagged EEGLAB EEG structure to database
s = db2mat(DB);                      % get empty structure to fill in
s.dataset_name = 'eeglab_tagged';    % dataset name is required
s.data = EEG;                        % set data to be stored
sUUID = mat2db(DB, s, true, 'Tags', {'EyeTrack', 'Oddball', 'AudioLeft'});

%% 6.3 reuse event types
s = db2mat(DB);                       % get empty structure to fill in
s.data = EEG;                    % store EEG with new set of event types
s.dataset_name = 'original EEG';
[~, uniqueEvents] = mat2db(DB, s, true);
s.dataset_name = 'EEG1';
[~, uniqueEvents] = mat2db(DB, s, true, 'EventTypes', uniqueEvents);

%% 7.1 retrieve dataset(s) based on UUID
datasets = db2mat(DB, sUUID);

%% 8.1 retrieve all datasets
s = getdb(DB, 'datasets', inf);           % retrieve all rows from datasets

%% 8.2 retrieve up to 10 datasets
s = getdb(DB, 'datasets', 10);  % retrieve a maximum of 10 rows from datasets

%% 8.3 retrieve up to 10 datasets whose names are 'eeg*'
s = getdb(DB, 'datasets', 0);         % get empty datasets structure
s.dataset_name = 'eeg*';              % dataset name must be 'eeg*'
sNew = getdb(DB, 'datasets', 10, s);   % retrieve these datasets

%% 8.4 retrieve up to 10 datasets whose names start with 'eeg*'
s = getdb(DB, 'datasets', 0);         % get empty datasets structure
s.dataset_name = 'eeg*';              % dataset name starts with 'eeg*'
sNew = getdb(DB, 'datasets', 10, s, 'RegExp', 'on'); % retrieve these datasets

%% 8.5 Retrieve up to 10 datasets whose names start with 'eeg' and that
% each have a tag 'EyeTrack' and either the tag 'VisualTarget' or a tag
% that starts with the phrase 'Audio'
s = getdb(DB, 'datasets', 0);     % get empty datasets structure
s.dataset_name = 'eeg*';          % dataset name starts with 'eeg'
sNew = getdb(DB, 'datasets', 10, s, 'RegExp', 'on',...
    'Tags', {{'EyeTrack'}, {'VisualTarget', 'Audio*'}});

%% 9.1 Update a dataset
commit(DB);                       % commit outstanding transactions
s = getdb(DB, 'datasets', 0);     % get an empty structure to
s.dataset_uuid = sUUID;
s = getdb(DB, 'datasets', 1, s);     % retrieve the dataset
s.dataset_description = 'dataset that comes with EEGLAB';
putdb(DB, 'datasets', s);
commit(DB);

%% 10.1 Store ten copies of the EEG dataset
s = db2mat(DB);                  % get empty structure to fill in
s.data = EEG;                    % set data to be stored
sNewF = cell(10, 1);             % save room to get created UUIDs
uniqueEvents = {};               % start with no event types and accumulate
for k = 1:10
    s.dataset_name = ['data' num2str(k) '.mat']; % set the dataset name
    [sNewF(k), uniqueEvents] = mat2db(DB, s, true, 'EventTypes', uniqueEvents);
end

%% 10.2 Retrieve all events associated with the dataset identified by UUID
s = getdb(DB, 'events', 0);      % get empty structure to fill in
s.event_entity_uuid = sNewF{1};      % search for events from a particular dataset
s.event_type_uuid = uniqueEvents{1};       % search for events only of a particular type
events = getdb(DB, 'events', inf, s);      % search for events from a particular dataset

%% 11.1 Create a tag �/Label/Event/Type�
commit(DB);                   % only need this if something is uncommitted
s = getdb(DB, 'tags', 0);      % get empty structure to fill in
s.tag_name = '/Label/Event/Type';
s.tag_entity_uuid = uniqueEvents{1};
s.tag_entity_class = 'event_types'; % name of table where entity is defined
putdb(DB, 'tags', s);         % store the tag
commit(DB);                   % be sure to commit

%% 11.2 Create eeglab tag for all datasets whose name start with eeglab
commit(DB);                   % only need this if something is uncommitted
s = getdb(DB, 'datasets', 0); % get empty structure to fill in
s.dataset_name = 'eeglab*';    % set search criteria
datasets = getdb(DB, 'datasets', inf, s, 'RegExp', 'on');
t = getdb(DB, 'tags', 0);      % get empty structure to fill in
for a = 1:length(datasets)
    t.tag_name = 'eeglab';
    t.tag_entity_class = 'datasets';
    t.tag_entity_uuid = datasets(a).dataset_uuid;
    putdb(DB, 'tags', t);         % store the tag
end
commit(DB);

%% 13.1 Load a dataset, filter it, and store the results in the database.
% Store original dataset in the database
load eeglab_data_ch.mat;             % load a previously saved EEG structure
s = db2mat(DB);                      % get empty structure
s.dataset_name = 'eeglab_data';      % dataset name is required
s.data = EEG;                        % set data to be stored
sUUID = mat2db(DB, s);               % store original dataset

% Filter the data and store the filtered dataset
EEG = pop_eegfilt(EEG, 1.0, 0, [], 0);  % filter an EEG dataset
s.dataset_name = 'eeglab_data_filtered.set';   % set up for storage
s.data = EEG;                   % put data in structure for storing
sNewF = mat2db(DB, s, true);    % store the filtered dataset

% Cache the transform for future quick retrieval
t = getdb(DB, 'transforms', 0); % retrieve an empty transform structure
t.transform_uuid = sNewF{1};    % set the fields
t.transform_string = ['pop_eegfilt((' sUUID{1} '),1.0,0,[],0)' ];
t.transform_description = 'Used EEGLAB FIR filter [1.0, 0]';
putdb(DB, 'transforms', t);     % set the fields
commit(DB);

%% 13.2 Use the transforms to retrieve the filtered data rather than recomputing the values.
t = getdb(DB, 'transforms', 0);   % retrieve an empty structure
t.transform_string = ['pop_eegfilt((' sUUID{1} '),1.0,0,[],0)' ];
cached = getdb(DB, 'transforms', inf, t); % get UUID of result
filtEEG = db2mat(DB, cached.transform_uuid); % get dataset

%% 14.1 Explode the data from an EEG structure as individual frames that can be searched.
load eeglab_data_ch.mat;             % load a previously saved EEG structure
sdef = db2data(DB);                         % get an empty template
sdef.data_def_format = 'NUMERIC_STREAM';    % set the format (required)
sdef.data_def_sampling_rate = EEG.srate;    % specify equally spaced samples
sdef.data = EEG.data;                       % set the data
sdef.data_def_description = [EEG.setname ' individual frames'];
sdefUUID = data2db(DB, sdef);       % store the individual frames in database

%% 14.2 Associate the data defined in Example 14.1 with the datasets whose UUIDs are contained in the array UUIDs
commit(DB);                               % well, it never hurts
smap = getdb(DB, 'data_maps', 0);         % get the template
smap.data_map_def_uuid = sdefUUID;        % UUID of data from Example 14.2
smap.data_map_structure_path = '/EEG/dataEx'; % load destination
for k = 1:length(UUIDs)
    smap.data_map_entity_uuid = UUIDs{k};
    smap.data_map_entity_class = 'datasets';
    putdb(DB, 'data_maps', smap);
end
commit(DB);

%% 15.1 Retrieve the data identified by the data definition UUID in the variable dUUID.
datadefs = db2data(DB, sdefUUID);

%% 15.2
smap = getdb(DB, 'data_maps', 0);    % get an empty data_map template
smap.data_map_entity_uuid = pUUID;   % find data items mapped to pUUID
dmaps = getdb(DB, 'data_maps', inf, smap); % find data map entries
datadef = db2data(DB, dmaps);       % retrieve all of those

%% 16.1 Store the array xray as a simple dataset.
s = db2mat(DB);
s.dataset_name = 'my simple dataset'; % dataset name is required
s.data = xray;                        % set data to be stored
s.dataset_modality = 'simple';        % dataset name is required
sUUID = mat2db(DB, s);                % store in database DB

