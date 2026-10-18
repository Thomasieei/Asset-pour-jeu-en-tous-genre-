#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/string.hpp>
#include <llama.h>
#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <vector>
using namespace godot;

class LoicLocalAI : public RefCounted {
    GDCLASS(LoicLocalAI, RefCounted)
    llama_model *model = nullptr;
    llama_context *context = nullptr;
    std::mutex lock;
    std::atomic<bool> stopped{false};
    static bool abort_decode(void *data) { return static_cast<LoicLocalAI *>(data)->stopped.load(); }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("load_model", "path", "threads"), &LoicLocalAI::load_model);
        ClassDB::bind_method(D_METHOD("generate", "prompt", "grammar", "max_tokens"), &LoicLocalAI::generate);
        ClassDB::bind_method(D_METHOD("cancel"), &LoicLocalAI::cancel);
    }
public:
    ~LoicLocalAI() {
        if (context) llama_free(context);
        if (model) llama_model_free(model);
    }
    bool load_model(String path, int threads) {
        std::lock_guard<std::mutex> guard(lock);
        if (model && context) return true;
        llama_backend_init();
        auto params = llama_model_default_params();
        params.n_gpu_layers = 0;
        params.load_mode = LLAMA_LOAD_MODE_MMAP;
        model = llama_model_load_from_file(path.utf8().get_data(), params);
        if (!model) return false;
        auto ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;
        ctx_params.n_batch = 256;
        ctx_params.n_ubatch = 128;
        ctx_params.n_threads = std::clamp(threads, 1, 4);
        ctx_params.n_threads_batch = ctx_params.n_threads;
        ctx_params.abort_callback = abort_decode;
        ctx_params.abort_callback_data = this;
        context = llama_init_from_model(model, ctx_params);
        if (!context) { llama_model_free(model); model = nullptr; return false; }
        return true;
    }
    void cancel() { stopped.store(true); }
    String generate(String input, String grammar, int limit) {
        std::lock_guard<std::mutex> guard(lock);
        if (!model || !context) return "";
        stopped.store(false);
        const auto *vocab = llama_model_get_vocab(model);
        auto utf = input.utf8();
        int n = -llama_tokenize(vocab, utf.get_data(), utf.length(), nullptr, 0, true, true);
        if (n <= 0 || n > 1800) return "";
        std::vector<llama_token> tokens(n);
        n = llama_tokenize(vocab, utf.get_data(), utf.length(), tokens.data(), n, true, true);
        if (n <= 0) return "";
        llama_memory_clear(llama_get_memory(context), true);
        for (int i = 0; i < n; i += 256) {
            auto batch = llama_batch_get_one(tokens.data()+i, std::min(256,n-i));
            if (stopped.load() || llama_decode(context,batch) != 0) return "";
        }
        auto *sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
        if (!grammar.is_empty()) {
            auto *g = llama_sampler_init_grammar(vocab,grammar.utf8().get_data(),"root");
            if (!g) { llama_sampler_free(sampler); return ""; }
            llama_sampler_chain_add(sampler,g);
        }
        llama_sampler_chain_add(sampler,llama_sampler_init_top_k(30));
        llama_sampler_chain_add(sampler,llama_sampler_init_temp(0.45f));
        llama_sampler_chain_add(sampler,llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
        std::string text;
        for (int i = 0; i < std::clamp(limit,1,180) && !stopped.load(); ++i) {
            llama_token token = llama_sampler_sample(sampler,context,-1);
            if (llama_vocab_is_eog(vocab,token)) break;
            char piece[256];
            int size = llama_token_to_piece(vocab,token,piece,sizeof(piece),0,false);
            if (size>0) text.append(piece,size);
            if (llama_decode(context,llama_batch_get_one(&token,1)) != 0) break;
        }
        llama_sampler_free(sampler);
        return String::utf8(text.c_str());
    }
};
void initialize_local_ai(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<LoicLocalAI>();
}
void uninitialize_local_ai(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT loic_local_ai_init(GDExtensionInterfaceGetProcAddress proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(proc,library,initialization);
    init.register_initializer(initialize_local_ai);
    init.register_terminator(uninitialize_local_ai);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
