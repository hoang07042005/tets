using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace freshfood_be.Services.AI
{
    public interface IAIService
    {
        Task<string> GetRecipeSuggestionAsync(List<string> ingredients);
    }

    public class AIService : IAIService
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;

        public AIService(HttpClient httpClient, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _apiKey = configuration["OpenAI:ApiKey"] ?? throw new ArgumentNullException("OpenAI ApiKey is missing");
        }

        public async Task<string> GetRecipeSuggestionAsync(List<string> ingredients)
        {
            var prompt = $@"Bạn là một chuyên gia đầu bếp tại Việt Nam. 
Dựa trên danh sách các nguyên liệu thực phẩm sau đây: {string.Join(", ", ingredients)}.
Hãy gợi ý 1 món ăn ngon nhất có thể nấu từ các nguyên liệu này.
Yêu cầu kết quả trả về bằng tiếng Việt, định dạng Markdown gồm:
1. Tên món ăn.
2. Tại sao món này lại phù hợp với các nguyên liệu trên.
3. Các nguyên liệu bổ sung cần thiết (nếu có).
4. Các bước nấu cơ bản (ngắn gọn).
Nếu danh sách nguyên liệu quá ít hoặc không thể nấu món gì, hãy gợi ý một món ăn phổ biến khác và giải thích tại sao.";

            var requestBody = new
            {
                model = "gpt-3.5-turbo",
                messages = new[]
                {
                    new { role = "system", content = "Bạn là trợ lý tư vấn món ăn thông minh của cửa hàng FreshFood." },
                    new { role = "user", content = prompt }
                },
                temperature = 0.7
            };

            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            request.Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            var response = await _httpClient.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                throw new Exception($"OpenAI API Error: {response.StatusCode} - {errorContent}");
            }

            var content = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(content);
            var result = doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString();

            return result ?? "Không thể tạo gợi ý lúc này.";
        }
    }
}
