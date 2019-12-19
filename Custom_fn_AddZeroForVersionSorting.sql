CREATE FUNCTION Custom_fn_AddZeroForVersionSorting (@version VARCHAR(250))
RETURNS VARCHAR(250)
AS
BEGIN
    DECLARE @sectionCount int;
    DECLARE @sectionIndex int;
    DECLARE @sectionSize int;
    DECLARE @section varchar(100);
    DECLARE @result varchar(250);

    SET @sectionSize = 7;
    SET @result = ''

    SET @sectionCount = LEN(@version) - LEN(REPLACE(@version, '.', '')) + 1;
    SET @sectionIndex = @sectionCount;
    WHILE @sectionIndex > 0
    BEGIN
        SET @section = PARSENAME(@version, @sectionIndex);
        WHILE LEN(@section) < @sectionSize
            BEGIN
                SET @section = '0' + @section;
            END;
        
        SET @result = @result + @section + '.';

        SET  @sectionIndex =  @sectionIndex - 1;
    
    END;
    SET @result = REVERSE(STUFF(REVERSE(@result), 1, 1, ''));

    RETURN @result;
END;
GO