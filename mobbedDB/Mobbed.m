% Mobbed connection object to a Postgresql database
%
% Usage:
%   >>  DB = Mobbed(name, hostname, user, password)
%   >>  DB = Mobbed(name, hostname, user, password, verbose)
%
% Description:
% DB = Mobbed(name, hostname, user, password) creates a connection
%   object to a Postgresql database called name on host hostname using
%   the username user with the specified password. The DB connection
%   object is used to read from and write to the database.
%
% DB = Mobbed(..., verbose) creates a connection object to a Postgresql
%    database. If verbose is false, then informative messages are
%    suppressed. If verbose is true (the default), then various
%    informative messages and timing information is output during
%    execution.
%
% Example 1:
% % Open a connection to an existing database called mobbed on local machine
%    DB = Mobbed('mobbed', 'localhost','postgres', 'admin');
%
% Example 2:
% % Retrieve up to 10 datasets that have been tagged 'Visual' from DB
%    sNew = getdb(DB, 'datasets', 10, 'Tag',{'Visual'});
%
% Example 3:
% % Create
% Notes:
%  - This class has static methods to create a database (createdb) and
%    delete a database (deletedb).
%  - Users can create multiple connections to the same database or
%    connections to different databases.
%
% See also:
%

% Copyright (C) 2012  Kay Robbins, Jeremy Cockfield, UTSA, {krobbins,jcockfie}@cs.utsa.edu
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

classdef Mobbed < hgsetget
    properties
        Verbose;
    end % public properties
    
    properties (Access = private)
        DbManager                   % Manager to database
    end % private properties
    
    methods
        
        function DB = Mobbed(name, hostname, user, password, varargin)
            % Create a connection object for database name on hostname
            parser = inputParser();
            parser.addRequired('name', @ischar);
            parser.addRequired('hostname', @ischar);
            parser.addRequired('user', @ischar);
            parser.addRequired('password', @ischar);
            parser.addOptional('verbose', true, @islogical);
            parser.parse(name, hostname, user, password, varargin{:});
            DB.Verbose = parser.Results.verbose;
            % Set the properties of a database
            DbHandler.addJavaPath();
            DB.DbManager = edu.utsa.mobbed.ManageDB(...
                parser.Results.name, parser.Results.hostname, ...
                parser.Results.user, parser.Results.password, ...
                parser.Results.verbose);
        end % Mobbed
        
        function close(DB)
            % Close the connection to database DB
            DB.DbManager.close();
        end % close
        
        function commit(DB)
            % Commit pending transaction(s) in database DB
            DB.DbManager.commit();
        end % commit
        
        function UUIDs = data2db(DB, datadefs)
            parser = inputParser();
            parser.addRequired('datadefs', @isstruct);
            parser.parse(datadefs);
            try
                UUIDs = putdb(DB, 'data_defs', rmfield(datadefs, 'data'));
                for a = 1:length(UUIDs)
                    datadefs(a).data_def_uuid = UUIDs{a};
                    DbHandler.storeDataDef(DB, datadefs(a));
                end
            catch ME
                try
                    DB.rollback();
                catch ME1
                    ME = addCause(ME, ME1);
                end
                throw(ME);
            end
            DB.commit();
        end
        
        function ddef = db2data(DB, varargin)
            % Retrieve additional data by data def uuid from DB
            parser = inputParser();
            parser.addOptional('sdefUUID', {}, @DbHandler.validateUUIDs);
            parser.parse(varargin{:});
            ddef = getdb(DB, 'data_defs', 0);
            ddef.data = [];
            if ~isempty(parser.Results.sdefUUID)
                UUIDsReformat = ...
                    DbHandler.reformatString(parser.Results.sdefUUID);
                numUUIDs = length(UUIDsReformat);
                ddef = repmat(ddef, 1, numUUIDs);
                for k = 1:numUUIDs
                    currentDataDef.data_def_uuid = UUIDsReformat{k};
                    currentDataDef = getdb(DB, 'data_defs', 1, ...
                        currentDataDef);
                    currentDataDef.data = DbHandler.retrieveDataDef(DB, ...
                        currentDataDef, false);
                    ddef(k) = currentDataDef;
                    currentDataDef = [];
                end
            end
        end % db2data
        
        function datasets = db2mat(DB, varargin)
            % Retrieve dataset(s) identified by UUIDs from DB
            parser = inputParser();
            parser.addOptional('UUIDs', [], @DbHandler.validateUUIDs);
            parser.parse(varargin{:});
            datasets = getdb(DB, 'datasets', 0);
            datasets.data = [];
            if ~isempty(parser.Results.UUIDs)
                UUIDsReformat = ...
                    DbHandler.reformatString(parser.Results.UUIDs);
                numUUIDs = length(UUIDsReformat);
                datasets = repmat(datasets, 1, numUUIDs);
                for k = 1:numUUIDs
                    currentDataset.dataset_uuid = UUIDsReformat{k};
                    currentDataset = getdb(DB, 'datasets', 1, ...
                        currentDataset);
                    currentDataset.data = ...
                        DbHandler.retrieveFile(DB, UUIDsReformat{k}, true);
                    datasets(k) = currentDataset;
                    currentDataset = [];
                end
            end
        end % db2mat
        
        function connection = getConnection(DB)
            connection = DB.DbManager.getConnection();
        end
        
        function outS = getdb(DB, table, limit, varargin)
            % Retrieve up to limit row(s) from table of DB
            parser = inputParser();
            parser.addRequired('table', @(x) ischar(x) && ~isempty(x));
            parser.addRequired('limit', @(x) isnumeric(x) && ...
                isscalar(x) && x > -1);
            parser.addOptional('inS', [], @(x) isstruct(x) && ...
                ~isempty(fieldnames(x)));
            parser.addParamValue('Tags', [], @iscell);
            parser.addParamValue('Attributes', [], @iscell);
            parser.addParamValue('RegExp', 'off', ...
                @(x) any(strcmpi(x, {'on', 'off'})));
            parser.parse(table, limit, varargin{:});
            columns = [];
            values =[];
            outS = [];
            tags = DbHandler.createJaggedArray(parser.Results.Tags);
            attributes = ...
                    DbHandler.createJaggedArray(parser.Results.Attributes);
            if parser.Results.limit == 0
                columns = cell(DB.DbManager.getColumnNames(...
                    parser.Results.table));
                outS = cell2struct(cell(length(columns),1), columns,1);
                return;
            end
            if ~isempty(parser.Results.inS)
                structFields = fieldnames(parser.Results.inS);
                structure = rmfield(parser.Results.inS, ...
                    structFields(structfun(@isempty,parser.Results.inS)));               
                columns = fieldnames(structure);
                values = DbHandler.createJaggedArray(struct2cell(structure));
            end
            outValues = ...
                cell(DB.DbManager.retrieveRows(parser.Results.table, ...
                parser.Results.limit, parser.Results.RegExp, tags, ...
                attributes, columns, values));
            if ~isempty(outValues)
                outColumns = cell(DB.DbManager.getColumnNames(...
                    parser.Results.table));
                outS = cell2struct(outValues, outColumns, 2);
            end
        end % getdb
        
        function [mStructure, extStructure] = extractdb(DB, inType, ...
                inS, outType, outS, limit, varargin)
            parser = inputParser();
            parser.addRequired('inType', @ischar);
            parser.addRequired('inS', @(x) isempty(x) || isstruct(x) && ...
                ~isempty(fieldnames(x)));
            parser.addRequired('outType', @ischar);
            parser.addRequired('outS', @(x) isempty(x) || isstruct(x) ...
                && ~isempty(fieldnames(x)));
            parser.addRequired('limit', @(x) isnumeric(x) && ...
                isscalar(x) && x > -1);
            parser.addParamValue('Range', [0,1], @(x) ...
                isnumeric(x) && isequal(size(x), [1,2]) && x(1) <= x(2));
            parser.addParamValue('RegExp', 'off', ...
                @(x) any(strcmpi(x, {'on', 'off'})));
            parser.parse(inType, inS, outType, outS, ...
                limit, varargin{:});
            inColumns = [];
            inValues = [];
            outColumns = [];
            outValues = [];
            mStructure = [];
            extStructure = [];
            if ~isempty(parser.Results.inS)
                inColumns = fieldnames(parser.Results.inS);
                inValues = struct2cell(parser.Results.inS);
            end
            if ~isempty(parser.Results.outS)
                outColumns = fieldnames(parser.Results.outS);
                outValues = struct2cell(parser.Results.outS);
            end
            mValues = cell(DB.DbManager.extractRows(...
                parser.Results.inType, inColumns, inValues, ...
                parser.Results.outType, outColumns, outValues, ...
                limit, parser.Results.RegExp, ...
                parser.Results.Range(1), parser.Results.Range(2)));
            if ~isempty(mValues)
                columns = cell(DB.DbManager.getColumnNames(...
                    parser.Results.inType));
                mStructure = ...
                    cell2struct(mValues, [columns; 'extracted'], 2);        
                evalues = cell(DB.DbManager.extractUniqueRows(...
                    mValues, limit));
                columns = cell(DB.DbManager.getColumnNames(...
                    parser.Results.outType));
                extStructure = cell2struct(evalues, columns, 2);
            end
        end % extractdb
        
        
        function [UUIDs, uniqueEvents] = mat2db(DB, datasets, varargin)
            % Insert dataset(s) in the dataset table of DB, returning UUIDs
            parser = inputParser();
            parser.addRequired('datasets', @isstruct);
            parser.addOptional('isUnique', true, @islogical);
            parser.addParamValue('Tags', {}, @(x) ischar(x) || ...
                iscellstr(x));
            parser.addParamValue('EventTypes', {}, @iscellstr);
            parser.parse(datasets, varargin{:});
            uniqueEvents = parser.Results.EventTypes;
            % Store the dataset(s)
            UUIDs = putdb(DB, 'datasets', rmfield(datasets, 'data'));
            numDatasets = length(datasets);
            % Store the tag(s)
            if ~isempty(parser.Results.Tags)
                tags = DbHandler.reformatString(parser.Results.Tags);
                numTags = length(tags);
                tags = repmat(tags, 1, numDatasets);
                entityUuids = repmat(UUIDs, 1, numTags);
                tagStruct = repmat(getdb(DB, 'tags', 0), 1, ...
                    numDatasets * numTags);
                [tagStruct.tag_name] = deal(tags{:});
                [tagStruct.tag_entity_uuid] = deal(entityUuids{:});
                [tagStruct.tag_entity_class] = deal('datasets');
                putdb(DB, 'tags', tagStruct);
            end
            for k = 1:numDatasets
                try
                    % Check the dataset modality
                    if ~isempty(datasets(k).dataset_modality_uuid)
                        modality.modality_uuid = ...
                            datasets(k).dataset_modality_uuid;
                        modality = getdb(DB, 'modalities', 1, modality);
                        if isempty(modality)
                            ME = MException(...
                                'VerifyModality:InvalidModality', ...
                                'Modality UUID does not exist');
                            throw(ME);
                        end
                        modalityName = modality.modality_name;
                        modality = [];
                    else
                        modalityName = 'EEG';
                    end
                    % Store elements, events, and actual data
                    if isfield(datasets(k), 'data') && ...
                            ~isempty(datasets(k).data)
                        uniqueEvents = ...
                            eval([modalityName ...
                            '_Modality.store(DB, UUIDs{k},' ...
                            'datasets(k).data, uniqueEvents)']);
                    end
                catch ME
                    try
                        DB.rollback();
                    catch ME1
                        ME = addCause(ME, ME1);
                    end
                    throw(ME);
                end
            end
            DB.commit();
        end % mat2db
        
        function UUIDs = putdb(DB, table, inS)
            % Insert or update row(s) in specified table of database DB
            parser = inputParser();
            parser.addRequired('table', @(x) ischar(x) && ~isempty(x));
            parser.addRequired('inS', @(x) isstruct(x) && ...
                ~isempty(fieldnames(x)));
            parser.parse(table, inS);
            columns = fieldnames(parser.Results.inS);
            doubleColumns = cell(DB.DbManager.getDoubleColumns(...
                parser.Results.table));           
            [values, doubleValues] = ...
                DbHandler.extractValues(parser.Results.inS, doubleColumns);
            UUIDs = cell(DB.DbManager.addRows(table, columns, values, ...
                doubleColumns, doubleValues));
        end % putdb
        
        function rollback(DB)
            % Rollback transaction(s) in database DB
            DB.DbManager.rollback();
        end % rollback
        
        function setAutoCommit(DB, autoCommit)
            % Set auto commit to true or false for database DB
            parser = inputParser();
            parser.addRequired('autoCommit', @islogical);
            parser.parse(autoCommit);
            DB.DbManager(autoCommit);
        end % setAutoCommit
        
    end % Public methods
    
    methods(Static)
        
        function createdb(name, hostname, user, password, script, varargin)
            % Create a Postgresql database called name on host hostname
            parser = inputParser();
            parser.addRequired('name', @ischar);
            parser.addRequired('hostname', @ischar);
            parser.addRequired('user', @ischar);
            parser.addRequired('password', @ischar);
            parser.addOptional('script', 'mobbed.sql', @ischar);
            parser.addOptional('verbose', true, @islogical);
            parser.parse(name, hostname, user, password, script, ...
                varargin{:});
            edu.utsa.mobbed.ManageDB.createDatabase(parser.Results.name, ...
                parser.Results.hostname, parser.Results.user, ...
                parser.Results.password, which(parser.Results.script), ...
                parser.Results.verbose);
        end % createdb
        
        function deletedb(name, hostname, user, password, varargin)
            % Delete Postgresql database name on host hostname
            parser = inputParser();
            parser.addRequired('name', @ischar);
            parser.addRequired('hostname', @ischar);
            parser.addRequired('user', @ischar);
            parser.addRequired('password', @ischar);
            parser.addOptional('verbose', true, @islogical);
            parser.parse(name, hostname, user, password, varargin{:});
            edu.utsa.mobbed.ManageDB.deleteDatabase(parser.Results.name, ...
                parser.Results.hostname, parser.Results.user, ...
                parser.Results.password, parser.Results.verbose);
        end % deletedb
        
    end % Static methods
    
end % MobbedDB