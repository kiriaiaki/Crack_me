#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

int Patch_File_Com (const char* Name_File, const unsigned char* Search_Bytes, const size_t Search_Len, const unsigned char *Replace_Bytes, size_t Replace_Len)
{
    if (!Name_File || !Search_Bytes || !Replace_Bytes || Search_Len != Replace_Len)
    {
        printf ("ERROR: Invalid parameters for patch\n");
        return -1;
    }

    FILE* File = fopen (Name_File, "rb+");
    if (!File)
    {
        printf ("ERROR: Cannot open file: %s\n", Name_File);
        return -1;
    }

    fseek (File, 0, SEEK_END);
    long Size = ftell (File);
    if (Size == -1)
    {
        fclose (File);
        printf ("ERROR: Failed to get file size\n");
        return -1;
    }

    rewind (File);
    ssize_t File_Size = (ssize_t) Size;

    unsigned char *Buffer = (unsigned char*) calloc (File_Size, sizeof (unsigned char*));
    if (!Buffer)
    {
        fclose (File);
        printf ("ERROR: Cannot allocate memory\n");
        return -1;
    }

    size_t Bytes_Read = fread (Buffer, 1, File_Size, File);
    if (Bytes_Read != (size_t) File_Size)
    {
        free (Buffer);
        fclose (File);
        printf ("ERROR: Cannot read file\n");
        return -1;
    }

    int A = 0;
    for (ssize_t i = 0; i <= File_Size - (ssize_t) Search_Len; i++)
    {
        if (memcmp (Buffer + i, Search_Bytes, Search_Len) == 0)
        {
            memcpy (Buffer + i, Replace_Bytes, Replace_Len);

            A = 1;

            break;
        }
    }

    if (A == 0)
    {
        free (Buffer);
        fclose (File);
        printf ("ERROR: Sequence not found in file\n");
        return -1;
    }

    char New_Name_File[1024] = {0};
    const char* dot = strrchr (Name_File, '.');
    if (dot && strcasecmp(dot, ".com") == 0)
    {
        size_t Base_Len = dot - Name_File;
        snprintf (New_Name_File, sizeof (New_Name_File), "%.*s_patched.com", (int) Base_Len, Name_File);
    }
    else
    {
        snprintf (New_Name_File, sizeof (New_Name_File), "%s_patched.com", Name_File);
    }

    FILE *New_File = fopen (New_Name_File, "wb");
    if (!New_File)
    {
        free (Buffer);
        fclose (File);
        printf ("ERROR: Cannot create patched file\n");
        return -1;
    }

    fwrite (Buffer, 1, File_Size, New_File);
    fclose(New_File);

    free (Buffer);
    fclose (File);

    return 0;
}

int main ()
{
    const char* Name_File = "Crack_Fil.com";

    unsigned char Search_Bytes[] = {0x75, 0x06};
    unsigned char Replace_Bytes[] = {0xEB, 0x06};

    size_t Search_Len = sizeof (Search_Bytes);
    size_t Replace_Len = sizeof (Replace_Bytes);

    int A = Patch_File_Com (Name_File, Search_Bytes, Search_Len, Replace_Bytes, Replace_Len);

    if (A == 0)
    {
        printf ("Patch applied successfully!\n");
        return 0;
    }
    else
    {
        printf ("Patch failed\n");
        return 1;
    }
}

