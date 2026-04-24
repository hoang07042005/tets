namespace freshfood_be.Services.Security;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = "freshfood";
    public string Audience { get; set; } = "freshfood";
    public string Key { get; set; } = "";
    public int ExpMinutes { get; set; } = 24 * 60;
}

