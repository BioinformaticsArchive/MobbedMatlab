function test_suite = testdeletedb %#ok<STOUT>
initTestSuite;

function tStruct = setup %#ok<DEFNU>
tStruct = struct('name', 'deletedb', 'hostname', 'localhost', ...
    'user', 'postgres', 'password', 'admin', 'DB', []);
try
    tStruct.DB = Mobbed(tStruct.name, tStruct.hostname, tStruct.user, ...
        tStruct.password, false);
catch ME %#ok<NASGU>
    Mobbed.createdb(tStruct.name, tStruct.hostname, tStruct.user, ...
        tStruct.password, 'mobbed.sql', false);
    tStruct.DB = Mobbed(tStruct.name, tStruct.hostname, tStruct.user, ...
        tStruct.password, false);
end

function testdeletedbExist(tStruct) %#ok<DEFNU>
fprintf('\nIt should delete a database that exists\n');
tStruct.DB.close();
Mobbed.deletedb(tStruct.name, tStruct.hostname, tStruct.user, ...
    tStruct.password, false);

function testdeletedbNotExist(tStruct) %#ok<DEFNU>
fprintf(['\nIt should throw an exception when deleting a database that' ...
    ' does not exist']);
tStruct.DB.close();
Mobbed.deletedb(tStruct.name, tStruct.hostname, tStruct.user, ...
    tStruct.password, false);
assertExceptionThrown(...
    @() error(Mobbed.deletedb(tStruct.name, tStruct.hostname, tStruct.user, ...
    tStruct.password, false)), ...
    'MATLAB:maxlhs');